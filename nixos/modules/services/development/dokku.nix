{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.dokku;
  dokkuLib = "/var/lib/dokku";
  dokkuRoot = "/home/dokku";
  logDir = "/var/log/dokku";
  certFile = "/etc/nginx/dhparam.pem";
  dokkuCmd = "${pkgs.dokku}/bin/dokku";
  pluginDir = "${pkgs.dokku}/lib/core-plugins/available";
  htmlErrorPath = "/data/nginx-vhosts/dokku-errors";
in {

  options.services.dokku = {
    enable = mkEnableOption "Dokku service";
  };

  config = mkIf (cfg.enable) {
    users.users.dokku = {
      name = "dokku";
      group = "dokku";
      home = "/home/dokku";
      extraGroups = [ "docker" "adm" ];
      createHome = true;
      useDefaultShell = true;
    };
    users.users.syslog = {
      name = "syslog";
      isSystemUser = true;
    };
    users.groups.dokku = {
      name = "dokku";
    };
    users.groups.adm = {
      name = "adm";
    };

    environment.systemPackages = with pkgs; [
      dokku
      sshcommand
      plugn
    ];

    # From plugins/00_dokku-standard/install
    systemd.services.dokku-standard-install = {
      description = "Dokku Standard Install";
      enable = true;
      script = ''
        mkdir -p ${dokkuLib}

        if [[ ! -f "${dokkuLib}/HOSTNAME" ]]; then
          ${pkgs.inetutils}/bin/hostname -f > ${dokkuLib}/HOSTNAME
        fi

        chown dokku:dokku ${dokkuLib}/HOSTNAME

        if [[ ! -f ${dokkuLib}/VHOST ]]; then
          [[ $(${pkgs.dnsutils}/bin/dig +short "$(<"${dokkuLib}/HOSTNAME")") ]] && cp ${dokkuLib}/HOSTNAME ${dokkuLib}/VHOST
        fi

        if [[ -f ${dokkuLib}/VHOST ]]; then
          chown dokku:dokku ${dokkuLib}/VHOST
        fi
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
      };
    };
    systemd.services.dokku-redeploy = {
      description = "Dokku app redeploy service";
      requires = [ "docker.service" ];
      after = [ "docker.service" ];
      wantedBy = [ "docker.service" ];
      serviceConfig = {
        Type = "simple";
        User = "dokku";
        ExecStart = "${dokkuCmd} ps:restore";
      };
    };

    # From plugins/20_events/install
    systemd.services.dokku-events-install = {
      description = "Dokku Events Install";
      enable = true;
      after = [ "nginx.service" "dokku-standard-install.service" ];
      script = ''
        echo "1"
        mkdir -m 755 -p ${logDir}
        echo "1.5"
        chgrp dokku ${logDir}
        echo "2"
        touch ${logDir}/events.log
        echo "2.5"
        chgrp dokku ${logDir}/events.log
        echo "3"
        chmod 644 ${logDir}/events.log
        echo "3.5"
        mkdir -p /var/log/nginx
        chgrp --quiet -R adm /var/log/nginx
        echo "4"
        [[ -f /etc/logrotate.d/nginx ]] && sed -i -e 's/create 0640 www-data dokku/create 0640 www-data adm/g' /etc/logrotate.d/nginx
        echo "5"

        mkdir -p ${dokkuLib}/data/nginx-vhosts/dokku-errors
        echo "6"
        cp ${pluginDir}/nginx-vhosts/templates/*-error.html ${dokkuLib}/data/nginx-vhosts/dokku-errors/.
        echo "7"
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
      };
    };

    services.rsyslogd = {
      enable = true;
      extraConfig = ''
        :syslogtag, contains, "dokku" ${logDir}/events.log
      '';
    };

    services.logrotate = {
      enable = true;
      config = ''
        ${logDir}/*.log {
          daily
          rotate 7
          missingok
          notifempty
          su syslog dokku
          compress
          delaycompress
          postrotate
                  reload rsyslog >/dev/null 2>&1 || true
          endscript
          create 664 syslog dokku
        }
      '';
    };

    # From /plugins/nginx-vhosts/install
    security.sudo = {
      enable = true;
      extraConfig = ''
        %dokku ALL=(ALL) NOPASSWD:${pkgs.libudev}/bin/systemctl reload nginx, ${pkgs.nginx}/sbin/nginx -t, ${pkgs.nginx}/sbin/nginx -t -c *
      '';
      #extraRules = [{
      #  users = [ "dokku" ];
      #  commands = [
      #    {command = "systemctl reload nginx"; options = ["NOPASSWD"];}
      #    {command = "${pkgs.nginx}/bin/nginx -t"; options = ["NOPASSWD"];}
      #    {command = "${pkgs.nginx}/bin/nginx -t -c *"; options = ["NOPASSWD"];}
      #  ];
      #}];
    };

    systemd.services.dokku-nginx-vhosts-install = {
      description = "Dokku NGINX VHosts Install";
      enable = true;
      after = [ "dokku-events-install.service" ];
      script = ''
        # If dhparam.pem has not been created, create it the first time
        mkdir -p /etc/nginx
        if [[ ! -f ${certFile} ]]; then
          ${pkgs.openssl}/bin/openssl dhparam -out ${certFile} 2048
        fi
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
      };
    };

    services.nginx = {
      enable = true;
      sslDhparam = "${certFile}";
      sslCiphers = "ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384";
      virtualHosts.dokku.extraConfig = ''
        include ${dokkuRoot}/*/nginx.conf
        ssl_session_cache shared:SSL:20m;
        ssl_session_timeout 1d;
        ssl_session_tickets on;
      '';
    };

    # From plugins/scheduler-docker-local/install
    systemd.services.dokku-retire = {
      description = "Dokku retire service";
      requires = [ "docker.service" ];
      after = [ "docker.service" ];
      wantedBy = [ "docker.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "dokku";
        ExecStart = "${dokkuCmd} ps:restore";
      };
    };
    systemd.timers.dokku-retire = {
      description = "Run dokku-retire.service every 5 minutes";
      timerConfig = {
        OnCalendar = "*:0/5";
      };
    };

    # From arch installer
    systemd.services.dokku = {
      description = "Dokku Mini-PaaS";
      enable = true;
      requires = [
        "dokku-standard-install.service"
        "dokku-events-install.service"
        "dokku-nginx-vhosts-install.service"
        "nginx.service"
        "logrotate.service"
        "syslog.service"
      ];
      after = [
        "dokku-standard-install.service"
        "dokku-events-install.service"
        "dokku-nginx-vhosts-install.service"
        "nginx.service"
        "logrotate.service"
        "syslog.service"
      ];
      script = ''
        ssh_dir=${dokkuLib}/.ssh
        echo "Configure dokku user"
        ${pkgs.sshcommand}/bin/sshcommand create dokku ${dokkuCmd}

        echo "Ensure proper sshcommand path"
        echo ${dokkuCmd} > "${dokkuLib}/.sshcommand"
        mkdir -p $ssh_dir
        touch $ssh_dir/authorized_keys
        if [[ -f .ssh/authorized_keys ]]; then
          sed -i.bak 's#${dokkuCmd}#' $ssh_dir/authorized_keys
          rm $ssh_dir/authorized_keys
        fi

        echo "Install all core plugins"
        #${dokkuCmd} plugin:install --core
      '';

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
      };
    };
  };
}

{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.dokku;

in {

  options.services.dokku = {
    enable = mkEnableOption "Dokku service";
  };

  config = mkIf (cfg.enable) {
    users.users.dokku = {
      name = "dokku";
      group = "dokku";
      home = "/home/dokku";
      extraGroups = [ "docker" ];
      createHome = true;
      useDefaultShell = true;
    };
    users.groups.dokku = {
      name = "dokku";
    };
    security.sudo = {
      enable = true;
      extraRules = [{
        users = [ "dokku" ];
        options = [ "NOPASSWD" ];
        commands = [
          "systemctl reload nginx"
          "${pkgs.nginx}/bin/nginx -t"
          "${pkgs.nginx}/bin/nginx -t -c *"
        ];
      }];
    };

    systemd.services.dokku-redeploy = {
      description = "Dokku app redeploy service";
      requires = [ "docker.service" ];
      after = [ "docker.service" ];
      wantedBy = [ "docker.service" ];
      serviceConfig = {
        Type = "simple";
        User = "dokku";
        ExecStart = "${pkgs.dokku}/bin/dokku ps:restore";
      } ;
    };
    services.rsyslogd = {
      enable = true;
      extraConfig = ''
        :syslogtag, contains, "dokku" /var/log/dokku/events.log
      '';
    };
    services.logrotate = {
      enable = true;
      config = ''
        /var/log/dokku/*.log {
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

    environment.systemPackages = with pkgs; [
      dokku
      sshcommand
      plugn
    ];

    services.nginx = {
      enable = true;
      sslDhparam = "/etc/nginx/dhparam.pem";
      sslCiphers = "ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384";
    };

    systemd.services.dokku = {
      description = "Dokku Mini-PaaS";
      enable = true;
      script = ''
        # if dhparam.pem has not been created, create it the first time
        if [[ ! -f /etc/nginx/dhparam.pem ]]; then
          openssl dhparam -out /etc/nginx/dhparam.pem 2048
        fi

        export DOKKU_LIB_ROOT=/var/lib/dokku
        export DOKKU_ROOT="/home/dokku"
        core_plugins_src=${pkgs.dokku}/lib/core-plugins/available
        core_plugins=$DOKKU_LIB_ROOT/core-plugins
        plugins=$DOKKU_LIB_ROOT/plugins
        data=$DOKKU_LIB_ROOT/data
        ssh_dir=$DOKKU_ROOT/.ssh

        touch /var/log/dokku/events.log

        echo "Configure dokku user"
        ${pkgs.sshcommand}/bin/sshcommand create dokku ${pkgs.dokku}/bin/dokku

        echo "Setting up storage directories"
        mkdir -p $data/storage
        chown dokku:dokku $data $data/storage

        echo "Ensure proper sshcommand path"
        echo ${pkgs.dokku}/bin/dokku > "$DOKKU_ROOT/.sshcommand"
        mkdir -p $ssh_dir
        touch $ssh_dir/authorized_keys
        #if [[ -f .ssh/authorized_keys ]]; then
        #  sed -i.bak 's#${pkgs.dokku}/bin/dokku#' $ssh_dir/authorized_keys
        #  rm $ssh_dir/authorized_keys
        #fi

        echo "Install all core plugins"
        #${pkgs.dokku}/bin/dokku plugin:install --core
      '';

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
      };
    };
  };
}

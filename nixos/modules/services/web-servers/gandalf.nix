{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.gandalf;
  gitdCfg = config.services.gitDaemon;

  basePath = "/var/lib/gandalf";
  templatePath = "/home/git/bare-template";
  configFile = pkgs.writeText "gandalf.conf" ''
    bin-path: ${pkgs.gandalf}/bin/gandalf-ssh
    database:
      url: ${config.services.mongodb.bind_ip}:27017
      name: gandalf
    git:
      bare:
        location: ${basePath}
        template: ${templatePath}
    host: ${cfg.hostAddress}
    webserver:
      port: "${cfg.hostAddress}:${cfg.hostPort}"
  '';
  preReceiveHook = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/tsuru/tsuru/1.6.0/misc/git-hooks/pre-receive";
    sha256 = "1kzsd07jv56m06dp76m8c2qrpkcabhsw52b10kn8ixxkb18ifik4";
  };

in {

  options.services.gandalf = {
    enable = mkEnableOption "Gandalf git server";

    hostPort = mkOption {
      default = "8000";
      description = "Host port";
    };

    hostAddress = mkOption {
      default = "127.0.0.1";
      description = "Host address";
    };
  };

  config = mkIf (cfg.enable) {

    environment.systemPackages = with pkgs; [
      gandalf
    ];

    users.users.git = {
      home = "/home/git";
      createHome = true;
    };

    services.mongodb.enable = true;

    services.gitDaemon = {
      enable = true;
      basePath = basePath;
      exportAll = true;
    };

    systemd.services.gandalf-git-hook-install = {
      description = "Git Hooks for Gandalf";
      enable = true;
      script = ''
        rm -f ${templatePath}/hooks/pre-receive
        mkdir -p ${templatePath}/hooks
        ln -s ${preReceiveHook} ${templatePath}/hooks/pre-receive
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
      };
    };

    systemd.services.gandalf-webserver = {
      description = "Gandalf Git Webserver";
      enable = true;
      after = [ "network.target" "gandalf-git-hook-install.service" ];
      requires = [ "gandalf-git-hook-install.service" ];
      before = [ "git-daemon.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.gandalf}/bin/gandalf-webserver --config=${configFile}";
        StateDirectory = "gandalf";
        StateDirectoryMode = 744;
      };
    };
  };
}

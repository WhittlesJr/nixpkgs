{ config, lib, pkgs, ... }:
with lib;

let
  cfg = config.services.appdaemon;

  defaultConfig = {
    log = {
      logfile = "${cfg.configDir}/appdaemon.log";
    };
    appdaemon = {
      threads = 10;
      plugins = {
        HASS = {
          type = "hass";
          ha_url = cfg.hassUrl;
          token=  cfg.token;
        };
      };
    };
  };

  configFile = pkgs.writeText "appdaemon.json"
    (builtins.toJSON (if cfg.applyDefaultConfig then
    (lib.recursiveUpdate defaultConfig cfg.config) else cfg.config));

in {
  options.services.appdaemon = {
    enable = mkEnableOption "AppDaemon Python automation service for Home Assistant";

    configDir = mkOption {
      default = "/var/lib/appdaemon/";
      type = types.string;
      description = "Config directory";
    };

    config = mkOption {
      default = null;
      type = with types; nullOr attrs;
      description = ''
        Your <filename>appdaemon.yaml</filename> as a Nix attribute set.
        Beware that setting this option will delete your previous <filename>appdaemon.yaml</filename>.
      '';
    };


    applyDefaultConfig = mkOption {
      default = true;
      type = types.bool;
      description = "Apply simple default config.";
    };

    hassUrl = mkOption {
      type = types.string;
      description = "URL of Home Assistant instance";
    };

    token = mkOption {
      type = types.string;
      description = "Long-lived access token to Home Assistant";
    };

  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      appdaemon
    ];

    systemd.services.appdaemon = {
      description = "AppDaemon";
      after = [ "home-assistant.target" ];
      preStart = lib.optionalString (cfg.config != null) ''
        config=${cfg.configDir}/appdaemon.yaml
        rm -f $config
        ${pkgs.remarshal}/bin/json2yaml -i ${configFile} -o $config
        chmod 444 $config
      '';
      serviceConfig = {
        ExecStart = "${pkgs.appdaemon}/bin/hass --config '${cfg.configDir}'";
        User = "hass";
        Group = "hass";
        Restart = "on-failure";
        ProtectSystem = "strict";
        ReadWritePaths = "${cfg.configDir}";
        KillSignal = "SIGINT";
        PrivateTmp = true;
        RemoveIPC = true;
      };
      path = [
        "/run/wrappers" # needed for ping
      ];
    };
  };
}

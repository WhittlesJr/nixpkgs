{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.hass-custom-alarm;
  hassConfig = config.services.home-assistant;
  configDir = hassConfig.configDir;
  files    = ["/www/alarm/alarm.css"
              "/www/lib/jquery-3.2.1.min.js"
              "/www/lib/countdown360.js"
              "/custom_components/alarm_control_panel/bwalarm.py"
              "/panels/alarm.html"];
in {
  options.services.hass-custom-alarm = {
    enable = mkEnableOption "Home Assistant Custom Alarm Panel";
  };

  config = mkIf cfg.enable {

    environment.systemPackages = with pkgs; [
      hass-custom-alarm
    ];

    services.home-assistant.config = {
      frontend = {
        javascript_version = "latest";
      };
    };

    systemd.services.hass-custom-alarm = {
      description = "Home Assistant Custom Alarm Panel";
      wantedBy = [ "home-assistant.service" ];
      script = lib.foldl (script: filePath: script + ''
          mkdir -p ${configDir}${builtins.dirOf filePath}
          rm -f ${configDir}${filePath}
          ln -s ${pkgs.hass-custom-alarm}${filePath} ${configDir}${filePath}
          '')
        "touch ${configDir}/alarm.yaml;" files;
      postStop = lib.foldl (postStop: filePath: postStop + ''
          rm -f ${configDir}${filePath}
          rmdir ${configDir}${builtins.dirOf filePath} &>/dev/null
          '')
        ""
        files;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "hass";
        Group = "hass";
      };
    };
  };

}

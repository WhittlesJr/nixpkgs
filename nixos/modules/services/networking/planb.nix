{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.planb;

in {

  options.services.planb = {
    enable = mkEnableOption "PlanB Redis-backed HTTP and websocket proxy";

    listenPort = mkOption {
      default = "8989";
      description = ''
        Port to listen on
      '';
    };

    listenAddress = mkOption {
      default = "0.0.0.0";
      description = ''
        Address to listen on
      '';
    };
  };

  config = mkIf (cfg.enable) {

    environment.systemPackages = with pkgs; [
      planb
    ];

    services.redis.enable = true;

    systemd.services.planb = {
      description = "PlanB Redis-backed HTTP and websocket proxy";
      enable = true;
      after = [
        "network.target"
        "redis.service"
      ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.planb}/bin/planb --listen ${cfg.listenAddress}:${cfg.listenPort}";
      };
    };
  };
}

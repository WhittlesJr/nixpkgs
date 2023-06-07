{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ankisyncd;

  syncUsers = builtins.listToAttrs (
    (builtins.map (index: let
      user = (elemAt cfg.users (index - 1));
    in
      {
        name = "SYNC_USER${toString index}";
        value = "${user.username}:${user.password}";
      }) (lib.range 1 ((builtins.length cfg.users))))
  );

  name = "ankisyncd";
in
{
  options.services.ankisyncd = {
    enable = mkEnableOption (lib.mdDoc "ankisyncd");

    package = mkOption {
      type = types.package;
      default = pkgs.anki;
      defaultText = literalExpression "pkgs.anki";
      description = lib.mdDoc "The package to use for the anki --syncserver command.";
    };

    host = mkOption {
      type = types.str;
      default = "localhost";
      description = lib.mdDoc "Sets the SYNC_HOST var for anki --syncserver";
    };

    port = mkOption {
      type = types.port;
      default = 27701;
      description = lib.mdDoc "Sets the SYNC_PORT var for anki --syncserver";
    };

    users = mkOption {
      description = lib.mdDoc "A list of credentials for your users. Populates SYNC_USER{n} vars.";
      type = types.listOf (types.submodule {
        options = {
          username = mkOption {
            type = types.str;
            description = lib.mdDoc "";
          };
          password = mkOption {
            type = types.str;
            description = lib.mdDoc "";
          };
        };
      });
    };

    openFirewall = mkOption {
      default = false;
      type = types.bool;
      description = lib.mdDoc "Whether to open the firewall for the specified port.";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];

    users.users."${name}" = {
      group = name;
      isSystemUser = true;
    };
    users.groups."${name}" = { };

    systemd.services."${name}" = {
      description = "${name} - Anki sync server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [ cfg.package ];

      environment = {
        SYNC_HOST = cfg.host;
        SYNC_PORT = toString cfg.port;
        SYNC_BASE = "/var/lib/${name}";
      } // syncUsers;
      serviceConfig = {
        Type = "simple";
        User = name;
        Group = name;
        #DynamicUser = true;
        StateDirectory = name;
        ExecStart = "${cfg.package}/bin/anki --syncserver";
        Restart = "always";
      };
    };
  };
}

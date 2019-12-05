{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.home-assistant;

  # cfg.config != null can be assumed here
  configJSON = pkgs.writeText "configuration.json"
    (builtins.toJSON (if cfg.applyDefaultConfig then
    (recursiveUpdate defaultConfig cfg.config) else cfg.config));
  configFile = pkgs.runCommand "configuration.yaml" { preferLocalBuild = true; } ''
    ${pkgs.remarshal}/bin/json2yaml -i ${configJSON} -o $out
  '';

  lovelaceConfigJSON = pkgs.writeText "ui-lovelace.json"
    (builtins.toJSON cfg.lovelaceConfig);
  lovelaceConfigFile = pkgs.runCommand "ui-lovelace.yaml" { preferLocalBuild = true; } ''
    ${pkgs.remarshal}/bin/json2yaml -i ${lovelaceConfigJSON} -o $out
  '';

  deviceAttrFilter = n: _: elem n [
    "area_id"
    "config_entries"
    "connections"
    "id"
    "identifiers"
    "manufacturer"
    "model"
    "name"
    "name_by_user"
    "sw_version"
    "via_device_id"
  ];

  entityAttrFilter = n: _: elem n [
    "config_entry_id"
    "device_id"
    "disabled_by"
    "entityID"
    "name"
    "platform"
    "unique_id"
  ];

  filterDeviceAttrs = device: (filterAttrs deviceAttrFilter device);
  filterEntityAttrs = entity: (filterAttrs entityAttrFilter entity);

  entityName = device:
               entity@{ name_suffix ? null, name ? null, ... }:
    if name != null then
      name
    else if name_suffix != null then
      device.name + name_suffix
    else
      device.name;

  entityID = device@{ entityID, ... }:
             entity@{ idPrefix, idSuffix ? null, id ? null, ... }:
    if id != null then
      id
    else if idSuffix != null then
      idPrefix + entityID + "_" + idSuffix
    else
      idPrefix + entityID;

  deviceEntities = device@{ entities, config_entries, ... }:
    (map
      (entity@{idPrefix, idSuffix, unique_id, ...}:
         (filterEntityAttrs device) //
         { config_entry_id = (head config_entries);
           device_id = device.id;
           name = (entityName device entity);
           entityID = (entityID device entity);
         } //
         (filterEntityAttrs entity))
      entities);

  deviceRegistry = {
    key = "core.device_registry";
    version = 1;
    data = {
      devices = (flatten (map filterDeviceAttrs cfg.devices));
    };
  };

  entityRegistry = {
    key = "core.entity_registry";
    version = 1;
    data = {
      entities = (map deviceEntities cfg.devices);
    };
  };

  deviceRegistryJSON = pkgs.writeText "core.device_registry.json"
    (builtins.toJSON deviceRegistry);
  entityRegistryJSON = pkgs.writeText "core.entity_registry.json"
    (builtins.toJSON entityRegistry);

  availableComponents = cfg.package.availableComponents;

  usedPlatforms = config:
    if isAttrs config then
      optional (config ? platform) config.platform
      ++ concatMap usedPlatforms (attrValues config)
    else if isList config then
      concatMap usedPlatforms config
    else [ ];

  # Given a component "platform", looks up whether it is used in the config
  # as `platform = "platform";`.
  #
  # For example, the component mqtt.sensor is used as follows:
  # config.sensor = [ {
  #   platform = "mqtt";
  #   ...
  # } ];
  useComponentPlatform = component: elem component (usedPlatforms cfg.config);

  # Returns whether component is used in config
  useComponent = component:
    hasAttrByPath (splitString "." component) cfg.config
    || useComponentPlatform component;

  # List of components used in config
  extraComponents = filter useComponent availableComponents;

  package = if (cfg.autoExtraComponents && cfg.config != null)
    then (cfg.package.override { inherit extraComponents; })
    else cfg.package;

  # If you are changing this, please update the description in applyDefaultConfig
  defaultConfig = {
    homeassistant.time_zone = config.time.timeZone;
    http.server_port = cfg.port;
  } // optionalAttrs (cfg.lovelaceConfig != null) {
    lovelace.mode = "yaml";
  };

in {
  meta.maintainers = with maintainers; [ dotlambda ];

  options.services.home-assistant = {
    enable = mkEnableOption "Home Assistant";

    configDir = mkOption {
      default = "/var/lib/hass";
      type = types.path;
      description = "The config directory, where your <filename>configuration.yaml</filename> is located.";
    };

    port = mkOption {
      default = 8123;
      type = types.int;
      description = "The port on which to listen.";
    };

    applyDefaultConfig = mkOption {
      default = true;
      type = types.bool;
      description = ''
        Setting this option enables a few configuration options for HA based on NixOS configuration (such as time zone) to avoid having to manually specify configuration we already have.
        </para>
        <para>
        Currently one side effect of enabling this is that the <literal>http</literal> component will be enabled.
        </para>
        <para>
        This only takes effect if <literal>config != null</literal> in order to ensure that a manually managed <filename>configuration.yaml</filename> is not overwritten.
      '';
    };

    config = mkOption {
      default = null;
      type = with types; nullOr attrs;
      example = literalExample ''
        {
          homeassistant = {
            name = "Home";
            time_zone = "UTC";
          };
          frontend = { };
          http = { };
          feedreader.urls = [ "https://nixos.org/blogs.xml" ];
        }
      '';
      description = ''
        Your <filename>configuration.yaml</filename> as a Nix attribute set.
        Beware that setting this option will delete your previous <filename>configuration.yaml</filename>.
      '';
    };

    configWritable = mkOption {
      default = false;
      type = types.bool;
      description = ''
        Whether to make <filename>configuration.yaml</filename> writable.
        This only has an effect if <option>config</option> is set.
        This will allow you to edit it from Home Assistant's web interface.
        However, bear in mind that it will be overwritten at every start of the service.
      '';
    };

    devices = mkOption {
      description = "";
      default = null;
      type = with types; nullOr (listOf (submodule {
        options = {
          registryConfig = mkOption {
            description = ''
              JSON config for this entity in <filename>.storage/core.device_registry.json</filename> as a Nix attribute set.
            '';
            type = nullOr attrs;
            default = null;
          };
          identifiers = mkOption {
            type = listOf str;
            description = ''
              The <code>identifiers</code> field in the registry for this device.
              This is used to find the device in <filename>.storage/core.entity_registry.json</filename> so it can be updated with the attributes provided in <config>registryConfig</config>.
            '';
          };
          entityIDBody = mkOption {
            type = str;
            description = ''
              The common main body of the entity names for this device's entities.
              For example, if your device adds the following entities:
                - zwave.front_door
                - sensor.front_door_sourcenodeid
                - sensor.front_door_burglar
                - sensor.front_door_battery_level
                - sensor.front_door_alarm_type
                - sensor.front_door_alarm_level
                - binary_sensor.front_door
              then "entityID" will be "front_door".
            '';
          };
          entities = mkOption {
            description = ''
              A list of the entities generated by this device.
            '';
            type = (listOf (submodule {
              options = {
                registryConfig = mkOption {
                  description = ''
                    JSON config for this entity in <filename>.storage/core.entity_registry.json</filename> as a Nix attribute set.
                    See https://www.home-assistant.io/docs/configuration/customizing-devices/

                  '';
                  type = nullOr attrs;
                  default = null;
                };
                deviceConfig = mkOption {
                  description = ''
                    As an alternative to supplying <config>services.home-assistant.config.zwave.device_config</config>, you may put that same per-entity configuration here.
                    This can help keep your entity config organized.
                  '';
                };
                inheritName = mkOption {
                  type = nullOr bool;
                  description = ''
                    The name for this entity should be taken from its parent device without changes.
                  '';
                };
                namePrefix = mkOption {
                  type = nullOr str;
                  description = ''
                    If given, the entity's name will be set to the device's name prepended by this string. This can be combined with <config>nameSuffix</config> and overwrites <config>inheritName</config>.
                  '';
                };
                nameSuffix = mkOption {
                  type = nullOr str;
                  description = ''
                    If given, the entity's name will be set to the device's name appended by this string. This can be combined with <config>namePrefix</config> and overwrites <config>inheritName</config>.
                  '';
                };
                uniqueId = mkOption {
                  type = str;
                  description = ''
                    Corresponds to <code>unique_id</code> in <filename>.storage/core.entity_registry.json</filename>.
                    This is used to find the entity in that file and modify it with our given config.
                  '';
                };
                idPrefix = mkOption {
                  type = str;
                  description = ''
                    The string before the dot in the entity name.
                    For example, the prefix for <code>binary_sensor.front_door</code> is <code>binary_sensor</code>.
                  '';
                };
                idSuffix = mkOption {
                  description = "";
                  type = str;
                  default = "";
                };
              };
            }));
          };
        };
      }));
    };
    lovelaceConfig = mkOption {
      default = null;
      type = with types; nullOr attrs;
      # from https://www.home-assistant.io/lovelace/yaml-mode/
      example = literalExample ''
        {
          title = "My Awesome Home";
          views = [ {
            title = "Example";
            cards = [ {
              type = "markdown";
              title = "Lovelace";
              content = "Welcome to your **Lovelace UI**.";
            } ];
          } ];
        }
      '';
      description = ''
        Your <filename>ui-lovelace.yaml</filename> as a Nix attribute set.
        Setting this option will automatically add
        <literal>lovelace.mode = "yaml";</literal> to your <option>config</option>.
        Beware that setting this option will delete your previous <filename>ui-lovelace.yaml</filename>
      '';
    };

    lovelaceConfigWritable = mkOption {
      default = false;
      type = types.bool;
      description = ''
        Whether to make <filename>ui-lovelace.yaml</filename> writable.
        This only has an effect if <option>lovelaceConfig</option> is set.
        This will allow you to edit it from Home Assistant's web interface.
        However, bear in mind that it will be overwritten at every start of the service.
      '';
    };

    package = mkOption {
      default = pkgs.home-assistant;
      defaultText = "pkgs.home-assistant";
      type = types.package;
      example = literalExample ''
        pkgs.home-assistant.override {
          extraPackages = ps: with ps; [ colorlog ];
        }
      '';
      description = ''
        Home Assistant package to use.
        Override <literal>extraPackages</literal> or <literal>extraComponents</literal> in order to add additional dependencies.
        If you specify <option>config</option> and do not set <option>autoExtraComponents</option>
        to <literal>false</literal>, overriding <literal>extraComponents</literal> will have no effect.
      '';
    };

    autoExtraComponents = mkOption {
      default = true;
      type = types.bool;
      description = ''
        If set to <literal>true</literal>, the components used in <literal>config</literal>
        are set as the specified package's <literal>extraComponents</literal>.
        This in turn adds all packaged dependencies to the derivation.
        You might still see import errors in your log.
        In this case, you will need to package the necessary dependencies yourself
        or ask for someone else to package them.
        If a dependency is packaged but not automatically added to this list,
        you might need to specify it in <literal>extraPackages</literal>.
      '';
    };

    openFirewall = mkOption {
      default = false;
      type = types.bool;
      description = "Whether to open the firewall for the specified port.";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];

    systemd.services.home-assistant = {
      description = "Home Assistant";
      after = [ "network.target" ];
      preStart = optionalString (cfg.config != null) (if cfg.configWritable then ''
        cp --no-preserve=mode ${configFile} "${cfg.configDir}/configuration.yaml"
      '' else ''
        rm -f "${cfg.configDir}/configuration.yaml"
        ln -s ${configFile} "${cfg.configDir}/configuration.yaml"
      '') + optionalString (cfg.lovelaceConfig != null) (if cfg.lovelaceConfigWritable then ''
        cp --no-preserve=mode ${lovelaceConfigFile} "${cfg.configDir}/ui-lovelace.yaml"
      '' else ''
        rm -f "${cfg.configDir}/ui-lovelace.yaml"
        ln -s ${lovelaceConfigFile} "${cfg.configDir}/ui-lovelace.yaml"
      '')
      + optionalString (cfg.devices != null) ''
        rm -f ${cfg.configDir}/.storage/core.device_registry_nix.json
        cp ${deviceRegistryJSON} ${cfg.configDir}/.storage/core.device_registry_nix.json
        rm -f ${cfg.configDir}/.storage/core.entity_registry_nix.json
        cp ${entityRegistryJSON} ${cfg.configDir}/.storage/core.entity_registry_nix.json

      '';
      serviceConfig = {
        ExecStart = "${package}/bin/hass --config '${cfg.configDir}'";
        User = "hass";
        Group = "hass";
        Restart = "on-failure";
        ProtectSystem = "strict";
        ReadWritePaths = "${cfg.configDir}";
        KillSignal = "SIGINT";
        PrivateTmp = true;
        RemoveIPC = true;
        AmbientCapabilities = "cap_net_raw,cap_net_admin+eip";
      };
      path = [
        "/run/wrappers" # needed for ping
      ];
    };

    systemd.targets.home-assistant = rec {
      description = "Home Assistant";
      wantedBy = [ "multi-user.target" ];
      wants = [ "home-assistant.service" ];
      after = wants;
    };

    users.users.hass = {
      home = cfg.configDir;
      createHome = true;
      group = "hass";
      uid = config.ids.uids.hass;
    };

    users.groups.hass.gid = config.ids.gids.hass;
  };
}

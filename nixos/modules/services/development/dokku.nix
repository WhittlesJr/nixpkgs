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
    };
    users.groups.dokku = {
      name = "dokku";
    };

    environment.systemPackages = with pkgs; [
      dokku
      sshcommand
      plugn
    ];

    systemd.services.dokku = {
      description = "Dokku Mini-PaaS";
      enable = true;
      script = ''
        export DOKKU_LIB_ROOT=/var/lib/dokku
        export DOKKU_ROOT="/home/dokku"
        core_plugins_src=${pkgs.dokku}/lib/core-plugins/available
        core_plugins=$DOKKU_LIB_ROOT/core-plugins
        plugins=$DOKKU_LIB_ROOT/plugins
        data=$DOKKU_LIB_ROOT/data
        ssh_dir=$DOKKU_ROOT/.ssh

        echo "Configure dokku user"
        ${pkgs.sshcommand}/bin/sshcommand create dokku ${pkgs.dokku}/bin/dokku

        echo "Setting up storage directories"
        mkdir -p $data/storage
        chown dokku:dokku $data $data/storage

        echo "Setting up plugin directories"
        mkdir -p $core_plugins/available
        mkdir -p $core_plugins/enabled
        touch $core_plugins/config.toml

        mkdir -p $plugins/available
        mkdir -p $plugins/enabled
        touch $plugins/config.toml

        echo "Enabling all core plugins"
        find $core_plugins_src -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | while read -r plugin; do
          if [ ! -d $plugins/available/$plugin ]; then
            ln -s $core_plugins_src/$plugin $plugins/available/$plugin
            PLUGIN_PATH=$core_plugins ${pkgs.plugn}/bin/plugn enable $plugin
            PLUGIN_PATH=$plugins ${pkgs.plugn}/bin/plugn enable $plugin
          fi
        done
        find -L $DOKKU_LIB_ROOT -type l -delete
        chown dokku:dokku -R $plugins $core_plugins

        echo "Ensure proper sshcommand path"
        echo ${pkgs.dokku}/bin/dokku > "$DOKKU_ROOT/.sshcommand"
        mkdir -p $ssh_dir
        touch $ssh_dir/authorized_keys
        #if [[ -f .ssh/authorized_keys ]]; then
        #  sed -i.bak 's#${pkgs.dokku}/bin/dokku#' $ssh_dir/authorized_keys
        #  rm $ssh_dir/authorized_keys
        #fi

        echo "Install all core plugins"
        ${pkgs.dokku}/bin/dokku plugin:install --core

        echo "Update version file"
        rm -f "$DOKKU_ROOT/VERSION"
        cp "${pkgs.dokku}/lib/VERSION" "$DOKKU_ROOT/VERSION"

        echo "Update hostname"
        ${pkgs.hostname}/bin/hostname -f > "$DOKKU_ROOT/HOSTNAME"
      '';

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
      };
    };
  };
}

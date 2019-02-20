{ lib, pkgs, stdenv, makeWrapper, buildGoPackage, fetchFromGitHub, bashInteractive }:

buildGoPackage rec {
  name = "dokku-${version}";
  version = "0.14.5";
  rev = "v${version}";

  goPackagePath = "github.com/dokku/dokku";

  src = fetchFromGitHub {
    inherit rev;
    owner = "dokku";
    repo = "dokku";
    sha256 = "0vs55qrh3y3px76hp3xsznrlbynhmkfvzvbx0diig5kcv9qjs14q";
  };

  buildInputs = with pkgs; [ makeWrapper ];

  goDeps = ./deps.nix;

  patches = [ ./nixos-compat.patch ];

  allowGoReference = true;
  #subPackages = [
  #  "plugins/config"
  #  "plugins/config/src/subcommands/export"
  #  "plugins/config/src/subcommands/set"
  #  "plugins/config/src/subcommands/get"
  #  "plugins/config/src/subcommands/bundle"
  #  "plugins/config/src/subcommands/keys"
  #  "plugins/config/src/subcommands/unset"
  #  "plugins/config/src/commands"
  #  "plugins/proxy"
  #  "plugins/network/src/subcommands/set"
  #  "plugins/network/src/subcommands/rebuild"
  #  "plugins/network/src/subcommands/report"
  #  "plugins/network/src/subcommands/rebuildall"
  #  "plugins/network/src/commands"
  #  "plugins/network/src/triggers/post-create"
  #  "plugins/network/src/triggers/install"
  #];

  buildPhase = ''
    runHook renameImports

    cd $NIX_BUILD_TOP/go/src/${goPackagePath}/
    GO_ARGS="" PLUGIN_MAKE_TARGET=build make go-build
  '';

  installPhase = ''
    dir=$NIX_BUILD_TOP/go/src/${goPackagePath}/

    # Set up plugin directories
    core_plugins=$bin/lib/core-plugins
    plugins=$bin/lib/plugins

  	mkdir -p {$core_plugins,$plugins}/enabled
  	mkdir -p {$core_plugins,$plugins}/available
  	touch    {$core_plugins,$plugins}/config.toml

    # Copy and enable all core plugins
    cp -r $dir/plugins/* $core_plugins/available
    find $core_plugins/available -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | while read -r plugin; do
      rm -rf $core_plugins/available/$plugin/{src,vendor,*.go,Makefile,glide*,.git*}
      ln -s $core_plugins/available/$plugin $core_plugins/enabled/$plugin
      ln -s $core_plugins/available/$plugin $plugins/available/$plugin
      ln -s $core_plugins/enabled/$plugin   $plugins/enabled/$plugin
    done

    # Add version file
    echo $rev > "$bin/VERSION"

    # Install dokku script
    mkdir -p $bin/bin
    install -Dm755 $dir/dokku $bin/bin/dokku
    patchShebangs $bin/bin/dokku
    wrapProgram $bin/bin/dokku \
      --set PLUGIN_PATH $plugins \
      --set PLUGIN_CORE_PATH $core_plugins \
      --set DOKKU_DRV $bin \
      --set PATH ${lib.makeBinPath [
        pkgs.git
        pkgs.dnsutils
        pkgs.plugn
        pkgs.docker
        pkgs.gliderlabs-sigil
        pkgs.nettools
        pkgs.nginx
        pkgs.procfile-util
        pkgs.rsyslog
        pkgs.coreutils
        pkgs.plugn
        pkgs.sshcommand
        pkgs.sudo
        pkgs.gnugrep
        pkgs.gnused
        pkgs.gawk
        pkgs.libuuid
        pkgs.which
        pkgs.su
        bashInteractive
        "$bin"
      ]}
  '';

  meta = with stdenv.lib; {
    homepage = http://dokku.viewdocs.io/dokku/;
    description = "The smallest PaaS implementation you've ever seen";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = with maintainers; [
      WhittlesJr
    ];
  };
}

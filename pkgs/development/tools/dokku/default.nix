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

  buildInputs = with pkgs; [
    makeWrapper
    dnsutils
    docker
    go
    gliderlabs-sigil
    nettools
    nginx
    procfile-util
    rsyslog
    coreutils
    plugn
    sshcommand
    libuuid
  ];

  goDeps = ./deps.nix;

  patches = [ ./drv-paths.patch ];

  postInstall = ''
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
      ln -s $core_plugins/available/$plugin $core_plugins/enabled/$plugin
      ln -s $core_plugins/available/$plugin $plugins/available/$plugin
      ln -s $core_plugins/enabled/$plugin   $plugins/enabled/$plugin
    done

    # Add version file
    echo $rev > "$bin/VERSION"

    # Add hostname file
    ${pkgs.hostname}/bin/hostname -f > "$bin/HOSTNAME"
    ${pkgs.hostname}/bin/hostname -f > "$bin/VHOST"

    # Install dokku script
    mkdir -p $bin/bin
    install -Dm755 $dir/dokku $bin/bin/dokku
    patchShebangs $bin/bin/dokku
    wrapProgram $bin/bin/dokku \
      --set DOKKU_LIB_PATH $bin/lib \
      --set DOKKU_DRV $bin \
      --set PATH ${lib.makeBinPath [
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

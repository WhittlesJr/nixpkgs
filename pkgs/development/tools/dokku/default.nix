{ lib, pkgs, stdenv, makeWrapper, buildGoPackage, fetchFromGitHub }:

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


  postInstall = ''
    dir=$NIX_BUILD_TOP/go/src/${goPackagePath}/

    # Apply plugin patches
    substituteInPlace $dir/plugins/common/functions \
      --replace /usr/bin/tty ${pkgs.coreutils}/bin/tty \
      --replace \$DOKKU_ROOT/HOSTNAME $bin/lib/HOSTNAME

    substituteInPlace $dir/plugins/00_dokku-standard/subcommands/version \
      --replace \$DOKKU_ROOT $bin/lib

    substituteInPlace $dir/plugins/nginx-vhosts/functions \
      --replace \$DOKKU_ROOT/HOSTNAME $bin/lib/HOSTNAME

    substituteInPlace $dir/plugins/domains/functions \
      --replace \$DOKKU_ROOT/HOSTNAME $bin/lib/HOSTNAME

    substituteInPlace $dir/plugins/00_dokku-standard/install \
      --replace \$DOKKU_ROOT/HOSTNAME $bin/lib/HOSTNAME

    # Copy core plugins
    mkdir -p $bin/lib/core-plugins/available
    cp -r $dir/plugins/* $bin/lib/core-plugins/available

    # Add version to lib path
    echo $rev > "$bin/lib/VERSION"

    # Add hostname to lib path
    ${pkgs.hostname}/bin/hostname -f > "$bin/lib/HOSTNAME"

    # Install dokku script
    mkdir -p $bin/bin
    install -Dm755 $dir/dokku $bin/bin/dokku
    patchShebangs $bin/bin/dokku
    wrapProgram $bin/bin/dokku \
      --set PLUGIN_CORE_AVAILABLE_PATH $core_plugins_src \
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

{ bashInteractive, pkgs, lib, stdenv, makeWrapper, fetchFromGitHub }:

stdenv.mkDerivation rec {
  name = "sshcommand-${version}";
  version = "0.7.0";
  rev = "v${version}";

  src = fetchFromGitHub {
    inherit rev;
    owner = "dokku";
    repo = "sshcommand";
    sha256 = "1hzs8wif6ysjmn98awn36gffhdf1nzksvfv49m43bm3kl2vcqgx0";
  };

  phases = [ "installPhase" ];

  buildInputs = with pkgs; [
    makeWrapper
    coreutils
    gnugrep
    gawk
  ];

  installPhase = ''
    mkdir -p $out/bin
    install -Dm755 $src/sshcommand $out/bin/sshcommand
    patchShebangs $out/bin/sshcommand
    wrapProgram $out/bin/sshcommand \
      --set PATH ${lib.makeBinPath [
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.gawk
        bashInteractive
      ]}
  '';

  meta = with stdenv.lib; {
    homepage = https://github.com/dokku/sshcommand;
    description = "Turn SSH into a thin client specifically for your app";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = with maintainers; [
      WhittlesJr
    ];
  };
}

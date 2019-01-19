{ stdenv, pkgs, fetchFromGitHub, ... }:

stdenv.mkDerivation rec {
  name = "hass-custom-alarm";
  version = "1.3.1";

  src = pkgs.fetchFromGitHub {
    owner = "gazoscalvertos";
    repo = "Hass-Custom-Alarm";
    rev = "v${version}";
    sha256 = "1xlwsyg45kmvx3gvkv7k5imbhkxan0s573lalkcqcflf078w7555";
  };

  buildInputs = [ pkgs.remarshal ];

  dontInstall = true;

  buildPhase = ''
    mkdir -p $out
    cp -r * $out/.
    ${pkgs.remarshal}/bin/yaml2json -i automation.yaml -o $out/automation.json
    ${pkgs.remarshal}/bin/yaml2json -i panel_custom.yaml -o $out/panel_custom.json
    ${pkgs.remarshal}/bin/yaml2json -i alarm.yaml -o $out/alarm.json
  '';
}

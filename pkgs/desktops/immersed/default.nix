{ stdenv, lib, fetchurl, pkgs,
  appimageTools
}:
appimageTools.wrapType2 { # or wrapType1
  name = "immersed";
  version = "9.6";
  src = fetchurl {
    url = "https://static.immersed.com/dl/Immersed-x86_64.AppImage";
    sha256 = "1m3p41ydh1npxn214jccfa4kxck3cqiifd5r9zrywzqcwci228sf";
  };
  extraPkgs = pkgs: with pkgs; [
    libthai
  ];
}

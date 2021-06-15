{ lib, stdenv, makeWrapper, glib, glibc,
  autoPatchelfHook,
  at-spi2-atk,
  at-spi2-core,
  cups,
  atk,
  mesa,
  c-ares,
  alsaLib,
  cairo,
  dbus,
  expat,
  ffmpeg,
  gnome2,
  gdk-pixbuf,
  gtk3,
  http-parser,
  libXScrnSaver,
  libappindicator-gtk2,
  libappindicator-gtk3,
  libdrm,
  libevent,
  libxkbcommon,
  libnotify,
  libvpx,
  libxcb,
  libxslt,
  libX11,
  libXcomposite,
  libXdamage,
  libXext,
  libXfixes,
  libXrandr,
  libXcursor,
  minizip,
  nspr,
  nss,
  pango,
  re2,
  snappy,
}:

stdenv.mkDerivation rec {
  pname = "everdo";
  version = "1.5.14";

  src = fetchTarball {
    url = "https://d11l8siwmn8w36.cloudfront.net/${version}/${pname}-${version}.pacman";
    sha256 = "1skqsjb429l6z1i0las2cj0gh33rkjwm304gjn0g1jb859irbs34";
  };

  buildInputs = [
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    dbus
    expat
    gdk-pixbuf
    gtk3
    libXScrnSaver
    libappindicator-gtk2
    libappindicator-gtk3
    libdrm
    libevent
    libnotify
    libvpx
    libX11
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libXrandr
    libxkbcommon
    libXcursor
    libxcb
    libxslt
    alsaLib
    nspr
    nss
    cups
    pango
    mesa
    c-ares
    gnome2.GConf
    http-parser
    minizip
    re2
    snappy
  ];

  nativeBuildInputs = [ autoPatchelfHook ];

  installPhase = ''
    mkdir -p $out/bin
    cp -r Everdo $out/lib
    cp -r share $out/share
    ln -s $out/lib/everdo $out/bin/everdo

    substituteInPlace $out/share/applications/everdo.desktop \
      --replace /opt/Everdo/everdo $out/lib/everdo

  '';

  meta = with lib; {
    description = "The Perfect App for GTD / Getting Things Done";
    homepage = "https://everdo.net/";
    license = null; # Unknown
    platforms = platforms.linux;
    maintainers = [ maintainers.WhittlesJr ];
  };
}

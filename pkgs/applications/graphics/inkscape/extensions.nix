{ lib, stdenv
, fetchFromGitHub
, runCommand
, inkcut
, callPackage
}:

{
  applytransforms = callPackage ./extensions/applytransforms { };

  hexmap = stdenv.mkDerivation {
    name = "hexmap";
    version = "2020-06-06";

    src = fetchFromGitHub {
      owner = "lifelike";
      repo = "hexmapextension";
      rev = "11401e23889318bdefb72df6980393050299d8cc";
      sha256 = "1a4jhva624mbljj2k43wzi6hrxacjz4626jfk9y2fg4r4sga22mm";
    };

    preferLocalBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/share/inkscape/extensions"
      cp -p *.inx *.py "$out/share/inkscape/extensions/"
      find "$out/share/inkscape/extensions/" -name "*.py" -exec chmod +x {} \;

      runHook postInstall
    '';

    meta = with lib; {
      description = "This is an extension for creating hex grids in Inkscape. It can also be used to make brick patterns of staggered rectangles";
      homepage = "https://github.com/lifelike/hexmapextension";
      license = licenses.gpl2Plus;
      maintainers = [ maintainers.raboof ];
      platforms = platforms.all;
    };
  };
  inkcut = (runCommand "inkcut-inkscape-plugin" {} ''
    mkdir -p $out/share/inkscape/extensions
    cp ${inkcut}/share/inkscape/extensions/* $out/share/inkscape/extensions
  '');

  silhouette = stdenv.mkDerivation rec {
    name = "inkscape-silhouette";
    version = "v1.25";

    src = fetchFromGitHub {
      owner = "fablabnbg";
      repo = "inkscape-silhouette";
      rev = version;
      sha256 = "03gcxvnfjns913b5l5bhysd70b7z2lgrv6855xgd9jnixrwcpdip";
    };

    preferLocalBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/share/inkscape/extensions"
      cp sendto_silhouette.* "$out/share/inkscape/extensions/"
      cp -R silhouette "$out/share/inkscape/extensions/"

      runHook postInstall
    '';

    meta = with lib; {
      description = "An extension to drive a Silhoutte Cameo and similar plotter devices from within inkscape.";
      homepage = "https://github.com/fablabnbg/inkscape-silhouette";
      license = licenses.gpl2;
      maintainers = [ maintainers.WhittlesJr ];
      platforms = platforms.all;
    };
  };
}

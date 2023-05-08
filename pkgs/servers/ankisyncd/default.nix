{ lib
, fetchFromGitHub
, python3
, anki
}:

python3.pkgs.buildPythonApplication rec {
  pname = "ankisyncd";
  version = "v2.4.0";
  src = fetchFromGitHub {
    owner = "ankicommunity";
    repo = "anki-sync-server";
    rev = version;
    sha256 = "087v4s2g67i7xx9rkhiyl82jxjmll7izp4yxyqir9a4v83az07i6";
  };
  format = "other";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/${python3.sitePackages}
    mkdir -p $out/share

    cp -r src/{ankisyncd,ankisyncd.conf} $out/${python3.sitePackages}
    cp -r src/ankisyncd_cli $out/share

    runHook postInstall
  '';

  fixupPhase = ''
    PYTHONPATH="$PYTHONPATH:$out/${python3.sitePackages}:${anki}/${python3.sitePackages}"

    makeWrapper "${python3.interpreter}" "$out/bin/ankisyncd" \
          --set PYTHONPATH $PYTHONPATH \
          --add-flags "-m ankisyncd"

    makeWrapper "${python3.interpreter}" "$out/bin/ankisyncctl" \
          --set PYTHONPATH $PYTHONPATH \
          --add-flags "$out/share/ankisyncd_cli/ankisyncctl.py"

    makeWrapper "${python3.interpreter}" "$out/bin/ankisync-migrate-user-tables" \
          --set PYTHONPATH $PYTHONPATH \
          --add-flags "$out/share/ankisyncd_cli/migrate_user_tables.py"
  '';

  nativeCheckInputs = with python3.pkgs; [
    pytest
    webtest
  ];

  buildInputs = [
    anki
  ];

  propagatedBuildInputs = with python3.pkgs; [
    decorator
    requests
  ];

  checkPhase = ''
    # skip these tests, our files are too young:
    # tests/test_web_media.py::SyncAppFunctionalMediaTest::test_sync_mediaChanges ValueError: ZIP does not support timestamps before 1980
    #pytest --ignore tests/test_web_media.py tests/
  '';

  meta = with lib; {
    description = "Self-hosted Anki sync server";
    maintainers = with maintainers; [ matt-snider WhittlesJr ];
    homepage = "https://github.com/ankicommunity/anki-sync-server";
    license = licenses.agpl3Only;
    platforms = platforms.linux;
  };
}

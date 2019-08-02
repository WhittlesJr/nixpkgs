{ lib
, pkgs
, buildPythonPackage
, fetchPypi
, python
, isPy37
, paste
, webob
, pyopenssl
}:

buildPythonPackage rec {
  pname = "poster3";
  version = "0.8.1";
  format = "wheel";

  disabled = ! isPy37;

  src = fetchPypi {
    inherit pname version;
    format = "wheel";
    python = "py3";
    sha256 = "1b27d7d63e3191e5d7238631fc828e4493590e94dcea034e386c079d853cce14";
  };

  checkInputs = [
    paste
    webob
    pyopenssl
  ];

  #postPatch = ''
  #  substituteInPlace tests/test_streaming.py \
  #    --replace "python2.6" "python"
  #'';

  doCheck = false;

  meta = {
    description = "Streaming HTTP uploads and multipart/form-data encoding";
    homepage = https://atlee.ca/software/poster/;
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ WhittlesJr ];
  };
}

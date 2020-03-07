{ lib, stdenv, buildPythonPackage, fetchPypi, isPy27, python
, darwin
, pytest
, mock
, ipaddress
, version ? "5.7.0"
}:

let
  versionMap = {
    "5.6.7" = {
      sha256 = "ffad8eb2ac614518bbe3c0b8eb9dffdb3a8d2e3a7d5da51c5b974fb723a5c5aa";
    };
    "5.7.0" = {
      sha256 = "03jykdi3dgf1cdal9bv4fq9zjvzj9l9bs99gi5ar81sdl5nc2pk8";
    };
  };
in

with versionMap.${version};

buildPythonPackage rec {
  pname = "psutil";
  inherit version;

  src = fetchPypi {
    inherit pname sha256 version;
  };

  # arch doesn't report frequency is the same way
  doCheck = stdenv.isx86_64;
  checkInputs = [ pytest ]
    ++ lib.optionals isPy27 [ mock ipaddress ];
  # out must be referenced as test import paths are relative
  # disable tests which don't work in sandbox
  # cpu_times is flakey on darwin
  checkPhase = ''
    pytest $out/${python.sitePackages}/psutil/tests/test_system.py \
      -k 'not user \
          and not disk_io_counters and not sensors_battery \
          and not cpu_times'
  '';

  buildInputs = lib.optionals stdenv.isDarwin [ darwin.IOKit ];

  pythonImportsCheck = [ "psutil" ];

  meta = with lib; {
    description = "Process and system utilization information interface for python";
    homepage = "https://github.com/giampaolo/psutil";
    license = licenses.bsd3;
    maintainers = with maintainers; [ jonringer ];
  };
}

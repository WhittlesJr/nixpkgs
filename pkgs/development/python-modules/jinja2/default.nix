{ stdenv
, buildPythonPackage
, isPy3k
, fetchPypi
, pytest
, markupsafe
, version ? "2.11.1"}:
let
  versionMap = {
    "2.8.1" = {
      sha256 = "35341f3a97b46327b3ef1eb624aadea87a535b8f50863036e085e7c426ac5891";
      doCheck = false;
    };
    "2.11.1" = {
      sha256 = "93187ffbc7808079673ef52771baa950426fd664d3aad1d0fa3e95644360e250";

      # Multiple tests run out of stack space on 32bit systems with python2.
      # See https://github.com/pallets/jinja/issues/1158
      doCheck = !stdenv.is32bit || isPy3k;
    };
  };
in

with versionMap.${version};

buildPythonPackage rec {
  pname = "Jinja2";
  inherit doCheck version;

  src = fetchPypi {
    inherit pname sha256 version;
  };

  checkInputs = [ pytest ];
  propagatedBuildInputs = [ markupsafe ];

  checkPhase = ''
    pytest -v tests
  '';

  meta = with stdenv.lib; {
    homepage = http://jinja.pocoo.org/;
    description = "Stand-alone template engine";
    license = licenses.bsd3;
    longDescription = ''
      Jinja2 is a template engine written in pure Python. It provides a
      Django inspired non-XML syntax but supports inline expressions and
      an optional sandboxed environment.
    '';
    maintainers = with maintainers; [ pierron sjourdois ];
  };
}

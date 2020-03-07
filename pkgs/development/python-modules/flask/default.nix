{ stdenv, buildPythonPackage, fetchPypi
, itsdangerous, click, werkzeug, jinja2, pytest
, version ? "1.1.1"}:

let
  versionMap = {
    "0.12.5" = {
      sha256 = "fac2b9d443e49f7e7358a444a3db5950bdd0324674d92ba67f8f1f15f876b14f";
    };
    "1.1.1" = {
      sha256 = "13f9f196f330c7c2c5d7a5cf91af894110ca0215ac051b5844701f2bfd934d52";
    };
  };
in

with versionMap.${version};

buildPythonPackage rec {
  pname = "Flask";
  inherit version;

  src = fetchPypi {
    inherit pname sha256 version;
  };

  checkInputs = [ pytest ];
  propagatedBuildInputs = [ itsdangerous click werkzeug jinja2 ];

  checkPhase = ''
    py.test
  '';

  # Tests require extra dependencies
  doCheck = false;

  meta = with stdenv.lib; {
    homepage = http://flask.pocoo.org/;
    description = "A microframework based on Werkzeug, Jinja 2, and good intentions";
    license = licenses.bsd3;
  };
}

{ lib
, pkgs
, buildPythonPackage
, fetchPypi
, fetchFromGitHub
, python

# Flake8
, flake8
, mccabe
, pep8
, pyflakes

# py.test
, covCore
, coverage
, py
, pytest
, pytestcov
, execnet
, pytestcache
, pytest-flake8
, pytest-sugar
, termcolor

# sphinx
, alabaster
, Babel
, docutils
, jinja2
, markupsafe
, pygments
, pytz
, six
, snowballstemmer
, sphinx
, sphinx_rtd_theme

# IPython
, ipython
}:

buildPythonPackage rec {
  pname = "easysnmp";
  version = "0.2.5";

  src = fetchPypi {
    inherit pname version;
    sha256 = "56cd64ce8d73d46a39b6166a750b0d1452657acf96adb51702aa5fd041b20f93";
  };
  #src = fetchFromGitHub {
  #  owner = "kamakazikamikaze";
  #  repo = pname;
  #  rev = "e6e8f7566414bf754d50360da04c05efe4f824d8";
  #  sha256 = "1zjw0698xg7jb726512zqk5jrhpmxmfxdw7zp15vh6c6q6kr03km";
  #};

  checkInputs = [
    # Flake8
    flake8
    mccabe
    pep8
    pyflakes

    # py.test
    covCore
    coverage
    py
    pytest
    pytestcov
    execnet
    pytestcache
    pytest-flake8
    pytest-sugar
    termcolor

    pkgs.net_snmp
  ];

  propagatedBuildInputs = [
    pkgs.net_snmp
    pkgs.openssl

    # sphinx
    alabaster
    Babel
    docutils
    jinja2
    markupsafe
    pygments
    pytz
    six
    snowballstemmer
    sphinx
    sphinx_rtd_theme

    # IPython
    ipython
  ];

  postFixup = ''
    patchelf --add-needed ${pkgs.net_snmp}/lib/libnetsnmp.so "$out/${python.sitePackages}/easysnmp/"*cpython*.so
  '';

  #patches = [./easysnmp.patch];
  #patchFlags = [ "-p1" "-l" ];
  doCheck = false;

  #LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.net_snmp ];
  #postInstall = ''
  # ln -s ${pkgs.net_snmp}/lib/libnetsnmp.so $out/${python.sitePackages}/easysnmp
  #'';

  meta = {
    description = "A blazingly fast and Pythonic SNMP library based on the official Net-SNMP bindings";
    homepage = https://easysnmp.readthedocs.io/en/latest/;
    license = src.LICENSE;
    maintainers = with lib.maintainers; [ WhittlesJr ];
  };
}

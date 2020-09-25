{ stdenv
, fetchPypi
, buildPythonPackage
, robotframework
}:

buildPythonPackage rec {
  pname = "pabot";
  version = "1.8.0";

  src = fetchPypi {
    inherit version;
    pname = "robotframework-pabot";
    sha256 = "dbae4340159875026540f6456922a5893431701cbbc2d165b6b24661e2ca665c";
    extension = "tar.gz";
  };

  propagatedBuildInputs = [ robotframework ];

  meta = with stdenv.lib; {
    description = "Parallel test runner for Robot Framework";
    homepage = "https://github.com/mkorpela/pabot";
    license = licenses.asl20;
    maintainers = with maintainers; [ WhittlesJr ];
  };
}

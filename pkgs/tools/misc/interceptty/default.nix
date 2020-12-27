{ stdenv, fetchFromGitHub, writeText, conf ? null }:

with stdenv.lib;

stdenv.mkDerivation rec {
  name = "interceptty";
  version = "0.6";

  src = fetchFromGitHub {
    owner = "geoffmeyers";
    repo = "interceptty";
    rev = "3b6fbbb748d6707a9287181eda66ff07b9629fab";
    sha256 = "078z3yki7c0rlw2z68jz0v3ykmcvqh1hjsl7h70f79rf47vvfmwv";
  };

  meta = {
    homepage = "https://github.com/geoffmeyers/interceptty.git";
    license = licenses.gpl2;
    description = "Intercept traffic to and from a serial port.";
    maintainers = with maintainers; [ WhittlesJr ];
  };
}

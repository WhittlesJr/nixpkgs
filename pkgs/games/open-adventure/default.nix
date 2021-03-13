{ lib, stdenv, fetchgit
}:

stdenv.mkDerivation rec {
  name    = "open-adventure";
  version = "1.9";

  src = fetchgit rec {
    url    = "https://gitlab.com/esr/open-adventure";
    rev = version;
    sha256 = "123svzy7xczdklx6plbafp22yv9bcvwfibjk0jv2c9i22dfsr07f";
  };

  meta = with lib; {
    description = "A forward-port of the Crowther/Woods Adventure 2.5 from 1995, last version in the main line of Colossal Cave Adventure development written by the original authors.";
    license = licenses.mit;
    maintainers = with maintainers; [ WhittlesJr ];
    homepage = "http://www.catb.org/~esr/open-adventure/";
  };

}

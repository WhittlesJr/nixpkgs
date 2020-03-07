{ aiohttp
, bottle
, buildPythonPackage
, celery
, certifi
, django
, falcon
, fetchPypi
, flask
, iana-etc
, isPy3k
, libredirect
, pyramid
, rq
, sanic
, sqlalchemy
, stdenv
, tornado
, urllib3
, version ? "0.13.5"
}:
let
  versionMap = {
    "0.13.2" = {
      sha256 = "ff1fa7fb85703ae9414c8b427ee73f8363232767c9cd19158f08f6e4f0b58fc7";
    };
    "0.13.5" = {
      sha256 = "c6b919623e488134a728f16326c6f0bcdab7e3f59e7f4c472a90eea4d6d8fe82";
    };
  };
in

with versionMap.${version};


buildPythonPackage rec {
  pname = "sentry-sdk";
  inherit version;

  src = fetchPypi {
    inherit pname sha256 version;
  };

  checkInputs = [ django flask tornado bottle rq falcon sqlalchemy ]
  ++ stdenv.lib.optionals isPy3k [ celery pyramid sanic aiohttp ];

  propagatedBuildInputs = [ urllib3 certifi ];

  meta = with stdenv.lib; {
    homepage = "https://github.com/getsentry/sentry-python";
    description = "New Python SDK for Sentry.io";
    license = licenses.bsd2;
    maintainers = with maintainers; [ gebner ];
  };

  # The Sentry tests need access to `/etc/protocols` (the tests call
  # `socket.getprotobyname('tcp')`, which reads from this file). Normally
  # this path isn't available in the sandbox. Therefore, use libredirect
  # to make on eavailable from `iana-etc`. This is a test-only operation.
  preCheck = ''
    export NIX_REDIRECTS=/etc/protocols=${iana-etc}/etc/protocols
    export LD_PRELOAD=${libredirect}/lib/libredirect.so
  '';
  postCheck = "unset NIX_REDIRECTS LD_PRELOAD";
}

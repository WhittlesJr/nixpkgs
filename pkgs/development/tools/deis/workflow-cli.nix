{ stdenv, buildGoPackage, fetchFromGitHub }:

buildGoPackage rec {
  name = "workflow-cli-${version}";
  version = "2.20.1";
  rev = "v${version}";

  goPackagePath = "github.com/teamhephy/workflow-cli";

  postInstall = ''
    mv $bin/bin/workflow-cli $bin/bin/deis
  '';

  src = fetchFromGitHub {
    inherit rev;
    owner = "teamhephy";
    repo = "workflow-cli";
    sha256 = "0mq6q45vwksajmpk7mk1swx8pfhbz6rrnhdjmf225qxjyi47d29s";
  };

  buildFlagsArray = [ "-ldflags=" "-X ${goPackagePath}/version.Version=${rev}" ];

  goDeps = ./workflow-cli-deps.nix;

  meta = with stdenv.lib; {
    homepage = https://teamhephy.info;
    description = "A command line utility used to interact with the Deis open source PaaS.";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = with maintainers; [
      WhittlesJr
    ];
  };
}

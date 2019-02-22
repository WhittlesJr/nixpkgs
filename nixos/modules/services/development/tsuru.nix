{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.tsuru;

  configFile = pkgs.writeText "tsuru.conf" ''
    listen: "0.0.0.0:${cfg.listenPort}"
    debug: ${if cfg.enableDebug then "true" else "false"}
    host: http://${cfg.hostAddress}:${cfg.listenPort}
    repo-manager: ${if cfg.enableGandalf then "gandalf" else "none"}
    auth:
        user-registration: true
        scheme: native
    database:
        url: ${config.services.mongodb.bind_ip}:27017
        name: tsurudb
    queue:
        mongo-url: ${config.services.mongodb.bind_ip}:27017
        mongo-database: queuedb
    provisioner: docker
    docker:
        router: hipache
        collection: docker_containers
        repository-namespace: tsuru
        deploy-cmd: /var/lib/tsuru/deploy
        bs:
            image: tsuru/bs:v1
            socket: /var/run/docker.sock
        cluster:
            storage: mongodb
            mongo-url: ${config.services.mongodb.bind_ip}:27017
            mongo-database: cluster
        run-cmd:
            bin: /var/lib/tsuru/start
            port: "8888"
    routers:
        hipache:
            type: hipache
            domain: <your-hipache-server-ip>.xip.io
            redis-server: <your-redis-server-with-port>
  '';
in {

  options.services.tsuru = {
    enable = mkEnableOption "Tsuru Docker-based PaaS";

    enableGandalf = mkEnableOption ''
      Connect to gandalf git webserver.
      Gandalf configuration exists under `services.gandalf`.
    '';

    enableDebug = mkEnableOption "Enable tsuru's debug logging";

    listenPort = mkOption {
      default = "8080";
      description = ''
        The port for the `listen` HTTP server config value.
      '';
    };
    hostAddress = mkOption {
      default = "127.0.0.1";
      description = ''
        Host address for `tsurud` to run on.
      '';
    };
  };

  config = mkIf (cfg.enable) {

    environment.systemPackages = with pkgs; [
      tsuru
      tsuru-client
      docker-machine
    ];

    virtualisation.virtualbox.host = {
      enable = true;
      addNetworkInterface = true;
      headless = true;
    };

    virtualisation.docker.enable = true;

    services.mongodb.enable = true;
    services.redis.enable = true;
    services.gandalf.enable = cfg.enableGandalf;

    systemd.services.tsuru = {
      description = "Tsuru PaaS";
      enable = true;
      after = [
        "network.target"
        "gandalf-webserver.service"
        "git-daemon.service"
        "mongodb.service"
        "redis.service"
      ];
      requires = [ "gandalf-webserver.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.tsuru}/bin/tsurud api --config ${configFile}";
      };
    };
  };
}

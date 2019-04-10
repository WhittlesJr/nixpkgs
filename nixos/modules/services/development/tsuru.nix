{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.tsuru;
  gandalfCfg = config.services.gandalf;
  dockerRegCfg = config.services.dockerRegistry;

  tsuruDefaultConfig = {
    auth = {
      hash-cost = 4;
      token-expire-days = 2;
      user-registration = true;
      scheme = "native";
    };
    database = {
      name = "tsurudb";
      url = "${config.services.mongodb.bind_ip}:27017";
    };
    debug = true;
    docker = {
      auto-scale = {
        enabled = true;
      };
      bs = {
        image = "tsuru/bs:v1";
        socket = "/var/run/docker.sock";
      };
      cluster = {
        mongo-database = "cluster";
        mongo-url = "${config.services.mongodb.bind_ip}:27017";
        storage = "mongodb";
      };
      collection = "docker";
      deploy-cmd = "/var/lib/tsuru/deploy";
      healing = {
        heal-containers-timeout = 30;
        active-monitoring-interval = 5;
      };
      #registry = "${dockerRegCfg.listenAddress}:${toString dockerRegCfg.port}";
      repository-namespace = "tsuru";
      router = "hipache";
      run-cmd = {
        bin = "/var/lib/tsuru/start";
        port = 8888;
      };
    };
    host = "http://127.0.0.1:8080";
    listen = "0.0.0.0:8080";
    provisioner = "docker";
    queue = {
      mongo-database = "queuedb";
      mongo-url = "${config.services.mongodb.bind_ip}:27017";
    };
    routers = {
      hipache = {
        type = "hipache";
        domain = "${config.services.planb.listenAddress}.xip.io";
        redis-server = "${config.services.redis.bind}:${toString config.services.redis.port}";
      };
    };
    use-tls = false;
  };

  tsuruGandalfConfig = {
    repo-manager = "gandalf";
    git = {
      api-server = "http://${gandalfCfg.hostAddress}:${gandalfCfg.hostPort}";
    };
  };

  tsuruManagedLocalIaaSConfig = {
    iaas = {
      dockermachine = {
        name = "local";
        driver = {
          name = "virtualbox";
        };
      };
    };
  };

  configFile = pkgs.writeText "tsuru-conf.json"
    (builtins.toJSON
      (if cfg.applyDefaultConfig
       then (lib.foldl' lib.recursiveUpdate {}
                        [tsuruDefaultConfig
                         (if cfg.enableGandalf then tsuruGandalfConfig else {})
                         (if cfg.simpleLocalManagedIaaS then tsuruManagedLocalIaaSConfig else {})
                         (if cfg.config != null then cfg.config else {})])
       else cfg.config));

in {
  meta.maintainers = with maintainers; [ WhittlesJr ];

  options.services.tsuru = {
    enable = mkEnableOption "Tsuru Docker-based PaaS";

    enableGandalf = mkEnableOption ''
      Add tsuru config that connects tsuru to your gandalf git webserver. Also sets <option>services.gandalf.enable</option> to <literal>true</literal>.
      Additional gandalf configuration exists under <option>services.gandalf</option>, but the defaults should be acceptable for simple use-cases.
    '';

    simpleLocalManagedIaaS = mkEnableOption ''
      Add tsuru config that gets you up and running with local <literal>docker-machine</literal>-managed IaaS, defaultly backed by virtualbox.
    '';

    applyDefaultConfig = mkOption {
      default = true;
      type = types.bool;
      description = ''
        The provided default config emulates that given by <literal>tsuru install-create</literal>.
      '';
    };

    config = mkOption {
      default = null;
      type = with types; nullOr attrs;
      description = ''
        Your <filename>tsuru.conf</filename> as a Nix attribute set.
        Beware that setting this option will delete your previous <filename>tsuru.conf</filename>.
      '';
    };
  };

  config = mkMerge [
    (mkIf (cfg.enable) {
   
       environment.systemPackages = with pkgs; [
         tsuru
         tsuru-client
       ];
   
       services.mongodb.enable = true;
       services.gandalf.enable = cfg.enableGandalf;
       services.planb.enable = true;
       services.redis.bind = "127.0.0.1";
       virtualisation.docker.enable = true;
       #services.dockerRegistry.enable = true;
   
       systemd.services.tsuru = {
         description = "Tsuru PaaS";
         enable = true;
         after = [
           "git-daemon.service"
           "mongodb.service"
           "planb.service"
           "docker.socket"
           "docker.service"
           #"docker-registry.service"
         ];
         requires = [
           "mongodb.service"
           "planb.service"
           "docker.socket"
           "docker.service"
           #"docker-registry.service"
         ];
         wantedBy = [ "multi-user.target" ];
         preStart =  ''
           config=/var/lib/tsuru/tsuru.conf
           rm -f $config
           ${pkgs.remarshal}/bin/json2yaml -i ${configFile} -o $config
           chmod 444 $config
         '';
   
         serviceConfig = {
           StateDirectory = "tsuru";
           ExecStart = "${pkgs.tsuru}/bin/tsurud api --config /var/lib/tsuru/tsuru.conf";
         };
       };
     })

     (mkIf cfg.simpleLocalManagedIaaS {
        virtualisation.virtualbox.host = {
          enable = true;
          addNetworkInterface = true;
          headless = true;
        };
        environment.systemPackages = with pkgs; [ docker-machine ];
     })
  ];
}

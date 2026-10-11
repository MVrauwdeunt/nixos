
{ config, lib, pkgs, ... }:

let
  cfg = config.apps.honcho;

  network = "honcho-internal";
  networkUnit = "podman-network-${network}.service";

  initSql = pkgs.writeText "honcho-init.sql" ''
    CREATE EXTENSION IF NOT EXISTS vector;
    CREATE EXTENSION IF NOT EXISTS pg_trgm;
  '';

  appEnvironment = {
    CACHE_URL = "redis://honcho-redis:6379/0?suppress=true";
    CACHE_ENABLED = "true";
    VECTOR_STORE_TYPE = "pgvector";
    AUTH_USE_AUTH = "false";
    SENTRY_ENABLED = "false";
    TELEMETRY_ENABLED = "false";
    TZ = "Etc/UTC";
  };

in
{
  options.apps.honcho = {
    enable = lib.mkEnableOption "Honcho AI memory";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/plastic-labs/honcho:latest";
      description = "Honcho container image";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/honcho";
      description = "Honcho persistent storage";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Honcho API host port";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow external access to Honcho";
    };
  };

  config = lib.mkIf cfg.enable {

    virtualisation.oci-containers.backend = "podman";

    # ------------------------------------------------------------
    # SOPS
    # ------------------------------------------------------------

    sops.secrets."vili/honcho/db-password" = {
      sopsFile = ../../secrets.yaml;
    };

    sops.secrets."vili/honcho/openai-key" = {
      sopsFile = ../../secrets.yaml;
    };

    sops.templates."honcho-db.env".content = ''
      POSTGRES_PASSWORD=${config.sops.placeholder."vili/honcho/db-password"}
    '';

    sops.templates."honcho.env".content = ''
      DB_CONNECTION_URI=postgresql+psycopg://honcho:${config.sops.placeholder."vili/honcho/db-password"}@honcho-db:5432/honcho
      LLM_OPENAI_API_KEY=${config.sops.placeholder."vili/honcho/openai-key"}
    '';

    # ------------------------------------------------------------
    # Persistent storage
    # ------------------------------------------------------------

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 root root -"
      "d ${cfg.dataDir}/postgres 0700 root root -"
      "d ${cfg.dataDir}/redis 0700 root root -"
    ];

    # ------------------------------------------------------------
    # Private network
    # ------------------------------------------------------------

    systemd.services.${"podman-network-" + network} = {
      description = "Create Honcho internal Podman network";
      wantedBy = [ "multi-user.target" ];

      path = [ pkgs.podman ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        podman network exists ${network} ||
          podman network create ${network}
      '';
    };

    # ------------------------------------------------------------
    # Service dependencies
    # ------------------------------------------------------------

    systemd.services.podman-honcho-db = {
      requires = [ networkUnit ];
      after = [ networkUnit ];
    };

    systemd.services.podman-honcho-redis = {
      requires = [ networkUnit ];
      after = [ networkUnit ];
    };

    systemd.services.podman-honcho = {
      requires = [
        networkUnit
        "podman-honcho-db.service"
        "podman-honcho-redis.service"
      ];

      after = [
        networkUnit
        "podman-honcho-db.service"
        "podman-honcho-redis.service"
      ];
    };

    systemd.services.podman-honcho-deriver = {
      requires = [
        networkUnit
        "podman-honcho.service"
      ];

      after = [
        networkUnit
        "podman-honcho.service"
      ];
    };

    # ------------------------------------------------------------
    # Containers
    # ------------------------------------------------------------

    virtualisation.oci-containers.containers = {

      honcho-db = {
        image = "docker.io/pgvector/pgvector:pg15";

        environment = {
          POSTGRES_USER = "honcho";
          POSTGRES_DB = "honcho";
          PGDATA = "/var/lib/postgresql/data/pgdata";
          TZ = "Etc/UTC";
        };

        environmentFiles = [
          config.sops.templates."honcho-db.env".path
        ];

        volumes = [
          "${cfg.dataDir}/postgres:/var/lib/postgresql/data"
          "${initSql}:/docker-entrypoint-initdb.d/init.sql:ro"
        ];

        extraOptions = [
          "--network=${network}"
        ];
      };

      honcho-redis = {
        image = "docker.io/library/redis:8";

        cmd = [
          "redis-server"
          "--appendonly"
          "yes"
        ];

        volumes = [
          "${cfg.dataDir}/redis:/data"
        ];

        extraOptions = [
          "--network=${network}"
        ];
      };

      honcho = {
        image = cfg.image;

        dependsOn = [
          "honcho-db"
          "honcho-redis"
        ];

        entrypoint = "sh";

        cmd = [
          "docker/entrypoint.sh"
        ];

        environment = appEnvironment;

        environmentFiles = [
          config.sops.templates."honcho.env".path
        ];

        ports = [
          "127.0.0.1:${toString cfg.port}:8000"
        ];

        extraOptions = [
          "--network=${network}"
          "--pull=always"
        ];
      };

      honcho-deriver = {
        image = cfg.image;

        dependsOn = [
          "honcho"
          "honcho-db"
          "honcho-redis"
        ];

        entrypoint = "/app/.venv/bin/python";

        cmd = [
          "-m"
          "src.deriver"
        ];

        environment = appEnvironment;

        environmentFiles = [
          config.sops.templates."honcho.env".path
        ];

        extraOptions = [
          "--network=${network}"
          "--pull=always"
        ];
      };
    };

    # ------------------------------------------------------------
    # Firewall
    # ------------------------------------------------------------

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}

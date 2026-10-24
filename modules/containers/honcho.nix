
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
      default = "ghcr.io/plastic-labs/honcho:v3.4.1@sha256:dc55e09c1df00374fc887b39d123d60b7a3556c9bbfdaea4b1d3da7a6fd87c36";
      description = "Official Honcho container image";
    };

    postgresImage = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/pgvector/pgvector:pg15@sha256:47af0b65960b14f1c6945aa4ccae37836c632e9a6fe0eea9160936e616e5b2e9";
      description = "PostgreSQL 15 with pgvector";
    };

    redisImage = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/library/redis:8@sha256:2c2dff791878316e3b083188be0d578423b24813cdda5de0e80ea4f7b3e6bfd6";
      description = "Redis 8 container image";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Honcho API localhost port";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open Honcho API port in firewall";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.podman.enable = true;
    virtualisation.oci-containers.backend = "podman";

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

    systemd.services."podman-network-${network}" = {
      description = "Create Honcho internal Podman network";
      wantedBy = [ "multi-user.target" ];

      before = [
        "podman-honcho-db.service"
        "podman-honcho-redis.service"
        "podman-honcho.service"
        "podman-honcho-deriver.service"
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        ${pkgs.podman}/bin/podman network exists ${network} \
          || ${pkgs.podman}/bin/podman network create ${network}
      '';
    };

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

    virtualisation.oci-containers.containers = {
      honcho-db = {
        image = cfg.postgresImage;

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
          "honcho-postgres:/var/lib/postgresql/data"
          "${initSql}:/docker-entrypoint-initdb.d/init.sql:ro"
        ];

        extraOptions = [
          "--network=${network}"
          "--pull=missing"
        ];
      };

      honcho-redis = {
        image = cfg.redisImage;

        cmd = [
          "redis-server"
          "--appendonly"
          "yes"
        ];

        volumes = [
          "honcho-redis:/data"
        ];

        extraOptions = [
          "--network=${network}"
          "--pull=missing"
        ];
      };

      honcho = {
        image = cfg.image;

        dependsOn = [
          "honcho-db"
          "honcho-redis"
        ];

        entrypoint = "sh";
        cmd = [ "docker/entrypoint.sh" ];

        environment = appEnvironment;

        environmentFiles = [
          config.sops.templates."honcho.env".path
        ];

        ports = [
          "127.0.0.1:${toString cfg.port}:8000"
        ];

        extraOptions = [
          "--network=${network}"
          "--pull=missing"
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

        environment = appEnvironment // {
          DERIVER_FLUSH_ENABLED = "true";
        };

        environmentFiles = [
          config.sops.templates."honcho.env".path
        ];

        extraOptions = [
          "--network=${network}"
          "--pull=missing"
        ];
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}

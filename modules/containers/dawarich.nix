{ config, lib, pkgs, ... }:

let
  cfg = config.apps.dawarich;
in
{
  options.apps.dawarich = {
    enable = lib.mkEnableOption "Dawarich";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {

    sops.secrets."saga/dawarich_db_password" = {};

    sops.templates."dawarich-db.env".content = ''
      POSTGRES_PASSWORD=${config.sops.placeholder."saga/dawarich_db_password"}
    '';

    sops.templates."dawarich-app.env".content = ''
      DATABASE_PASSWORD=${config.sops.placeholder."saga/dawarich_db_password"}
    '';

    systemd.tmpfiles.rules = [
      "d /var/lib/dawarich 0755 root root -"
      "d /var/lib/dawarich/db 0755 root root -"
      "d /var/lib/dawarich/public 0755 root root -"
      "d /var/lib/dawarich/storage 0755 root root -"
      "d /var/lib/dawarich/watched 0755 root root -"
    ];

    systemd.services.dawarich-network = {
      description = "Create Dawarich Podman network";

      wantedBy = [ "multi-user.target" ];

      before = [
        "podman-dawarich-db.service"
        "podman-dawarich-redis.service"
        "podman-dawarich.service"
        "podman-dawarich-sidekiq.service"
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        ${pkgs.podman}/bin/podman network exists dawarich \
          || ${pkgs.podman}/bin/podman network create dawarich
      '';
    };

    systemd.services.podman-dawarich-db = {
      requires = [ "dawarich-network.service" ];
      after = [ "dawarich-network.service" ];
    };

    systemd.services.podman-dawarich-redis = {
      requires = [ "dawarich-network.service" ];
      after = [ "dawarich-network.service" ];
    };

    systemd.services.podman-dawarich = {
      requires = [ "dawarich-network.service" ];
      after = [ "dawarich-network.service" ];
    };

    systemd.services.podman-dawarich-sidekiq = {
      requires = [ "dawarich-network.service" ];
      after = [ "dawarich-network.service" ];
    };

    virtualisation.oci-containers.containers = {

      dawarich-db = {
        image = "docker.io/postgis/postgis:17-3.5-alpine";

        volumes = [
          "/var/lib/dawarich/db:/var/lib/postgresql/data"
        ];

        environment = {
          POSTGRES_USER = "dawarich";
          POSTGRES_DB = "dawarich_development";
        };

        environmentFiles = [
          config.sops.templates."dawarich-db.env".path
        ];

        extraOptions = [
          "--network=dawarich"
          "--network-alias=dawarich_db"
          "--shm-size=1g"
        ];
      };

      dawarich-redis = {
        image = "docker.io/library/redis:7.4-alpine";

        extraOptions = [
          "--network=dawarich"
          "--network-alias=dawarich_redis"
        ];
      };

      dawarich = {
        image = "docker.io/freikin/dawarich:latest";

        dependsOn = [
          "dawarich-db"
          "dawarich-redis"
        ];

        entrypoint = "web-entrypoint.sh";

        cmd = [
          "bin/rails"
          "server"
          "-p"
          "3000"
          "-b"
          "::"
        ];

        ports = [
          "127.0.0.1:${toString cfg.port}:3000"
        ];

        volumes = [
          "/var/lib/dawarich/public:/var/app/public"
          "/var/lib/dawarich/watched:/var/app/tmp/imports/watched"
          "/var/lib/dawarich/storage:/var/app/storage"
          "/var/lib/dawarich/db:/dawarich_db_data"
        ];

        environment = {
          RAILS_ENV = "development";

          REDIS_URL = "redis://dawarich_redis:6379";

          DATABASE_HOST = "dawarich_db";
          DATABASE_USERNAME = "dawarich";
          DATABASE_NAME = "dawarich_development";

          MIN_MINUTES_SPENT_IN_CITY = "60";

          APPLICATION_HOSTS =
            "localhost,dawarich.fiordland-gar.ts.net";

          TIME_ZONE = "Europe/Amsterdam";
          APPLICATION_PROTOCOL = "http";

          PROMETHEUS_EXPORTER_ENABLED = "false";
          PROMETHEUS_EXPORTER_HOST = "0.0.0.0";
          PROMETHEUS_EXPORTER_PORT = "9394";

          SELF_HOSTED = "true";
          STORE_GEODATA = "true";
        };

        environmentFiles = [
          config.sops.templates."dawarich-app.env".path
        ];

        extraOptions = [
          "--network=dawarich"
        ];
      };

      dawarich-sidekiq = {
        image = "docker.io/freikin/dawarich:latest";

        dependsOn = [
          "dawarich-db"
          "dawarich-redis"
          "dawarich"
        ];

        entrypoint = "sidekiq-entrypoint.sh";

        cmd = [
          "sidekiq"
        ];

        volumes = [
          "/var/lib/dawarich/public:/var/app/public"
          "/var/lib/dawarich/watched:/var/app/tmp/imports/watched"
          "/var/lib/dawarich/storage:/var/app/storage"
        ];

        environment = {
          RAILS_ENV = "development";

          REDIS_URL = "redis://dawarich_redis:6379";

          DATABASE_HOST = "dawarich_db";
          DATABASE_USERNAME = "dawarich";
          DATABASE_NAME = "dawarich_development";

          APPLICATION_HOSTS = "localhost";

          BACKGROUND_PROCESSING_CONCURRENCY = "10";

          APPLICATION_PROTOCOL = "http";

          PROMETHEUS_EXPORTER_ENABLED = "false";
          PROMETHEUS_EXPORTER_HOST = "dawarich";
          PROMETHEUS_EXPORTER_PORT = "9394";

          SELF_HOSTED = "true";
          STORE_GEODATA = "true";
        };

        environmentFiles = [
          config.sops.templates."dawarich-app.env".path
        ];

        extraOptions = [
          "--network=dawarich"
        ];
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
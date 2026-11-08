
{ config, lib, pkgs, ... }:

let
  cfg = config.apps.immich;

  images = {
    server =
      "ghcr.io/immich-app/immich-server:v3.3.5@sha256:485d546a2e31d6a8b4db8423fcba5c109de8c218d93410af115fd1ccfc4352a6";

    machineLearning =
      "ghcr.io/immich-app/immich-machine-learning:v3.3.5@sha256:5b28c9352c8374b8a1ed96fbdd8d6755fea6e43510ec43fdf6538aa02ea40f56";

    database =
      "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:bcf63357191b76a916ae5eb93464d65c07511da41e3bf7a8416db519b40b1c23";

    valkey =
      "docker.io/valkey/valkey:9.1.2@sha256:c123e3715db63d06d4ad6964884037aa0d5d4d703939b9929954112889708e1d";
  };
in
{
  imports = [
    (import ./common.nix {
      name = "immich";
      image = images.server;

      port = 2283;
      bindAddress = "127.0.0.1";

      tailscaleDefault = true;

      mountConfig = false;
      createDataDir = false;

      usePuidPgid = false;
      bridgeNetwork = false;
      disableHealthcheck = false;

      extraVolumes = [
        "/mnt/Volume2/Afbeeldingen/upload:/usr/src/app/upload"
      ];

      environment = {
        DB_HOSTNAME = "immich-database";
        DB_USERNAME = "immich";
        DB_DATABASE_NAME = "immich";

        REDIS_HOSTNAME = "immich-redis";

        IMMICH_MEDIA_LOCATION = "/usr/src/app/upload";
      };

      extraOptions = [
        "--network=immich"
      ];
    })

    (import ./common.nix {
      name = "immich-database";
      image = images.database;

      port = 5432;
      publishedPorts = [ ];

      dataDir = "/var/lib/immich/postgres";
      configMount = "/var/lib/postgresql/data";
      createDataDir = false;

      useTimezone = false;
      usePuidPgid = false;
      bridgeNetwork = false;
      disableHealthcheck = false;

      environment = {
        POSTGRES_USER = "immich";
        POSTGRES_DB = "immich";
        POSTGRES_INITDB_ARGS = "--data-checksums";
      };

      extraOptions = [
        "--network=immich"
        "--shm-size=128m"
      ];
    })

    (import ./common.nix {
      name = "immich-redis";
      image = images.valkey;

      port = 6379;
      publishedPorts = [ ];

      mountConfig = false;
      createDataDir = false;

      useTimezone = false;
      usePuidPgid = false;
      bridgeNetwork = false;
      disableHealthcheck = false;

      extraOptions = [
        "--network=immich"
      ];
    })

    (import ./common.nix {
      name = "immich-machine-learning";
      image = images.machineLearning;

      port = 3003;
      publishedPorts = [ ];

      mountConfig = false;
      createDataDir = false;

      useTimezone = false;
      usePuidPgid = false;
      bridgeNetwork = false;
      disableHealthcheck = false;

      extraVolumes = [
        "immich-model-cache:/cache"
      ];

      extraOptions = [
        "--network=immich"
      ];
    })
  ];

  options.apps.immich = {
    tailscale.serviceName = lib.mkOption {
      type = lib.types.str;
      default = "photos";
      description = "Tailscale Service name.";
    };
  };

  config = lib.mkMerge [
    {
      apps.immich-database.enable = cfg.enable;
      apps.immich-redis.enable = cfg.enable;
      apps.immich-machine-learning.enable = cfg.enable;
    }

    (lib.mkIf cfg.enable {
      sops.secrets."saga/immich_db_password" = {};

      sops.templates."immich-db.env".content = ''
        POSTGRES_PASSWORD=${config.sops.placeholder."saga/immich_db_password"}
      '';

      sops.templates."immich-server.env".content = ''
        DB_PASSWORD=${config.sops.placeholder."saga/immich_db_password"}
      '';

      systemd.tmpfiles.rules = [
        "d /var/lib/immich 0755 root root -"
        "d /var/lib/immich/postgres 0755 root root -"
      ];

      systemd.services.podman-network-immich = {
        description = "Create Immich Podman network";
        wantedBy = [ "multi-user.target" ];

        before = [
          "podman-immich.service"
          "podman-immich-database.service"
          "podman-immich-redis.service"
          "podman-immich-machine-learning.service"
        ];

        serviceConfig.Type = "oneshot";

        script = ''
          ${pkgs.podman}/bin/podman network exists immich \
            || ${pkgs.podman}/bin/podman network create immich
        '';
      };

      systemd.services.podman-immich = {
        requires = [ "podman-network-immich.service" ];
        after = [ "podman-network-immich.service" ];
      };

      systemd.services.podman-immich-database = {
        requires = [ "podman-network-immich.service" ];
        after = [ "podman-network-immich.service" ];
      };

      systemd.services.podman-immich-redis = {
        requires = [ "podman-network-immich.service" ];
        after = [ "podman-network-immich.service" ];
      };

      systemd.services.podman-immich-machine-learning = {
        requires = [ "podman-network-immich.service" ];
        after = [ "podman-network-immich.service" ];
      };

      virtualisation.oci-containers.containers = {
        immich = {
          dependsOn = [
            "immich-database"
            "immich-redis"
            "immich-machine-learning"
          ];

          environmentFiles = [
            config.sops.templates."immich-server.env".path
          ];
        };

        immich-database.environmentFiles = [
          config.sops.templates."immich-db.env".path
        ];
      };
    })
  ];
}

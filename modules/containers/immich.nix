{ config, lib, pkgs, ... }:

let
  cfg = config.apps.immich;
in
{
  options.apps.immich = {
    enable = lib.mkEnableOption "Immich";

    port = lib.mkOption {
      type = lib.types.port;
      default = 2283;
      description = "Local Immich web port.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the Immich port in the firewall.";
    };

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Immich through Tailscale Services.";
    };

    tailscale.serviceName = lib.mkOption {
      type = lib.types.str;
      default = "photos";
      description = "Tailscale Service name.";
    };
  };

  config = lib.mkIf cfg.enable {
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
      immich-database = {
        image = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0";
        pull = "always";

        environment = {
          POSTGRES_USER = "immich";
          POSTGRES_DB = "immich";
          POSTGRES_INITDB_ARGS = "--data-checksums";
        };

        environmentFiles = [
          config.sops.templates."immich-db.env".path
        ];

        volumes = [
          "/var/lib/immich/postgres:/var/lib/postgresql/data"
        ];

        extraOptions = [
          "--network=immich"
        ];
      };

      immich-redis = {
        image = "docker.io/valkey/valkey:9";
        pull = "always";

        extraOptions = [
          "--network=immich"
        ];
      };

      immich-machine-learning = {
        image = "ghcr.io/immich-app/immich-machine-learning:release";
        pull = "always";

        volumes = [
          "immich-model-cache:/cache"
        ];

        extraOptions = [
          "--network=immich"
        ];
      };

      immich = {
        image = "ghcr.io/immich-app/immich-server:release";
        pull = "always";

        dependsOn = [
          "immich-database"
          "immich-redis"
          "immich-machine-learning"
        ];

        ports = [
          "127.0.0.1:${toString cfg.port}:2283"
        ];

        environment = {
          DB_HOSTNAME = "immich-database";
          DB_USERNAME = "immich";
          DB_DATABASE_NAME = "immich";
          REDIS_HOSTNAME = "immich-redis";
          TZ = "Europe/Amsterdam";
        };

        environmentFiles = [
          config.sops.templates."immich-server.env".path
        ];

        volumes = [
          "/mnt/Volume2/Afbeeldingen/upload:/usr/src/app/upload"
        ];

        extraOptions = [
          "--network=immich"
        ];
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
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

    systemd.tmpfiles.rules = [
      "d /var/lib/dawarich 0755 root root -"
      "d /var/lib/dawarich/db 0755 root root -"
    ];

    systemd.services.dawarich-network = {
      description = "Create Dawarich Podman network";
      wantedBy = [ "multi-user.target" ];

      before = [
        "podman-dawarich-db.service"
        "podman-dawarich-redis.service"
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
    };
  };
}

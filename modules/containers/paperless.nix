{ config, lib, ... }:

let
  cfg = config.apps.paperless;
in
{
  options.apps.paperless = {
    enable = lib.mkEnableOption "Paperless";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
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
    systemd.services.paperless-network = {
      description = "Create Paperless Podman network";
      before = [
        "podman-paperless-db.service"
        "podman-paperless-redis.service"
      ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        ${config.virtualisation.podman.package}/bin/podman network exists paperless \
          || ${config.virtualisation.podman.package}/bin/podman network create paperless
      '';
    };

    virtualisation.oci-containers.containers = {
      paperless-db = {
        image = "docker.io/library/mariadb:11";

        volumes = [
          "/var/lib/paperless/database:/var/lib/mysql"
        ];

        environment = {
          MARIADB_DATABASE = "paperless";
          MARIADB_USER = "paperless";
          MARIADB_PASSWORD = "paperless";
          MARIADB_ROOT_PASSWORD = "paperless";
        };

        extraOptions = [
          "--network=paperless"
          "--network-alias=db"
        ];
      };

      paperless-redis = {
        image = "docker.io/library/redis:8";

        extraOptions = [
          "--network=paperless"
          "--network-alias=broker"
        ];
      };
    };
  };
}
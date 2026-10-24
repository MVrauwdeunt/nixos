
{ config, lib, pkgs, ... }:

let
  cfg = config.apps.paperless;
in
{
  options.apps.paperless = {
    enable = lib.mkEnableOption "Paperless-ngx";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Local Paperless web port.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Paperless through Tailscale Services.";
    };
  };

  config = lib.mkIf cfg.enable {

    #
    # Secrets
    #
    sops.secrets."saga/paperless_secret_key" = {};
    sops.secrets."saga/paperless_db_password" = {};
    sops.secrets."saga/paperless_db_root_password" = {};

    sops.templates."paperless-db.env".content = ''
      MARIADB_PASSWORD=${config.sops.placeholder."saga/paperless_db_password"}
      MARIADB_ROOT_PASSWORD=${config.sops.placeholder."saga/paperless_db_root_password"}
    '';

    sops.templates."paperless.env".content = ''
      PAPERLESS_SECRET_KEY=${config.sops.placeholder."saga/paperless_secret_key"}
      PAPERLESS_DBPASS=${config.sops.placeholder."saga/paperless_db_password"}
    '';

    #
    # Persistent directories
    #
    systemd.tmpfiles.rules = [
      "d /var/lib/paperless 0755 root root -"
      "d /var/lib/paperless/database 0755 - - -"
      "d /var/lib/paperless/data 0755 - - -"
    ];

    #
    # Shared Podman network
    #
    systemd.services.paperless-network = {
      description = "Create Paperless Podman network";

      wantedBy = [ "multi-user.target" ];

      before = [
        "podman-paperless-db.service"
        "podman-paperless-redis.service"
        "podman-paperless.service"
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        ${pkgs.podman}/bin/podman network exists paperless \
          || ${pkgs.podman}/bin/podman network create paperless
      '';
    };

    #
    # Ensure network exists before containers start
    #
    systemd.services.podman-paperless-db = {
      requires = [ "paperless-network.service" ];
      after = [ "paperless-network.service" ];
    };

    systemd.services.podman-paperless-redis = {
      requires = [ "paperless-network.service" ];
      after = [ "paperless-network.service" ];
    };

    systemd.services.podman-paperless = {
      requires = [ "paperless-network.service" ];
      after = [ "paperless-network.service" ];
    };

    #
    # Containers
    #
    virtualisation.oci-containers.containers = {

      #
      # MariaDB
      #
      paperless-db = {
        image = "docker.io/library/mariadb@sha256:f16d7a344413e519dff518f27bdb221388f84b0d274c97c4fb5f2cb0dc1b34fa";
        pull = "missing";

        volumes = [
          "/var/lib/paperless/database:/var/lib/mysql"
        ];

        environment = {
          MARIADB_DATABASE = "paperless";
          MARIADB_USER = "paperless";
        };

        environmentFiles = [
          config.sops.templates."paperless-db.env".path
        ];

        extraOptions = [
          "--network=paperless"
          "--network-alias=db"
        ];
      };

      #
      # Redis
      #
      paperless-redis = {
        image = "docker.io/library/redis@sha256:2c2dff791878316e3b083188be0d578423b24813cdda5de0e80ea4f7b3e6bfd6";
        pull = "missing";

        extraOptions = [
          "--network=paperless"
          "--network-alias=broker"
        ];
      };

      #
      # Paperless-ngx
      #
      paperless = {
        image = "ghcr.io/paperless-ngx/paperless-ngx@sha256:d232cba37cc0bab0d6c6581ecd320383b7a6f49f33e0fd16adda4d009eb600dd";
        pull = "missing";

        dependsOn = [
          "paperless-db"
          "paperless-redis"
        ];

        ports = [
          "127.0.0.1:${toString cfg.port}:8000"
        ];

        volumes = [
          "/var/lib/paperless/data:/usr/src/paperless/data"

          "/mnt/Volume2/Documenten/paperless/media:/usr/src/paperless/media"
          "/mnt/Volume2/Documenten/export:/usr/src/paperless/export"
          "/mnt/Volume2/Documenten/scanned:/usr/src/paperless/consume"
        ];

        environment = {
          PAPERLESS_URL = "https://paperless.fiordland-gar.ts.net";

          PAPERLESS_REDIS = "redis://broker:6379";

          PAPERLESS_DBENGINE = "mariadb";
          PAPERLESS_DBHOST = "db";
          PAPERLESS_DBUSER = "paperless";
          PAPERLESS_DBPORT = "3306";
        };

        environmentFiles = [
          config.sops.templates."paperless.env".path
        ];

        extraOptions = [
          "--network=paperless"
        ];
      };
    };

    #
    # Normally closed because access goes through Tailscale
    #
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}

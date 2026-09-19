{ config, lib, pkgs, ... }:

let
  cfg = config.apps.adventurelog;
  apiCfg = config.apps.adventureapi;
in
{
  options.apps.adventurelog = {
    enable = lib.mkEnableOption "AdventureLog";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8015;
      description = "Local AdventureLog frontend port.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose AdventureLog through Tailscale Services.";
    };
  };

  options.apps.adventureapi = {
    enable = lib.mkEnableOption "AdventureLog API";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8016;
      description = "Local AdventureLog API port.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose the AdventureLog API through Tailscale Services.";
    };
  };

  config = lib.mkIf cfg.enable {
    apps.adventureapi = {
      enable = true;
      tailscale.enable = cfg.tailscale.enable;
    };

    sops.secrets."saga/adventurelog_db_password" = {};
    sops.secrets."saga/adventurelog_secret_key" = {};
    sops.secrets."saga/adventurelog_admin_password" = {};

    sops.templates."adventurelog-db.env".content = ''
      POSTGRES_PASSWORD=${config.sops.placeholder."saga/adventurelog_db_password"}
    '';

    sops.templates."adventurelog-api.env".content = ''
      POSTGRES_PASSWORD=${config.sops.placeholder."saga/adventurelog_db_password"}
      PGPASSWORD=${config.sops.placeholder."saga/adventurelog_db_password"}
      SECRET_KEY=${config.sops.placeholder."saga/adventurelog_secret_key"}
      DJANGO_ADMIN_PASSWORD=${config.sops.placeholder."saga/adventurelog_admin_password"}
    '';

    systemd.tmpfiles.rules = [
      "d /var/lib/adventurelog 0755 root root -"
      "d /var/lib/adventurelog/postgres 0755 root root -"
      "d /var/lib/adventurelog/media 0755 1000 1000 -"
    ];

    systemd.services.podman-network-adventurelog = {
      description = "Create AdventureLog Podman network";
      wantedBy = [ "multi-user.target" ];

      before = [
        "podman-adventurelog.service"
        "podman-adventureapi.service"
        "podman-adventurelog-db.service"
      ];

      serviceConfig.Type = "oneshot";

      script = ''
        ${pkgs.podman}/bin/podman network exists adventurelog \
          || ${pkgs.podman}/bin/podman network create adventurelog
      '';
    };

    systemd.services.podman-adventurelog = {
      requires = [ "podman-network-adventurelog.service" ];
      after = [ "podman-network-adventurelog.service" ];
    };

    systemd.services.podman-adventureapi = {
      requires = [ "podman-network-adventurelog.service" ];
      after = [ "podman-network-adventurelog.service" ];
    };

    systemd.services.podman-adventurelog-db = {
      requires = [ "podman-network-adventurelog.service" ];
      after = [ "podman-network-adventurelog.service" ];
    };

    virtualisation.oci-containers.containers = {
      adventurelog-db = {
        image = "docker.io/postgis/postgis:16-3.5";
        pull = "always";

        environment = {
          POSTGRES_DB = "database";
          POSTGRES_USER = "adventure";
        };

        environmentFiles = [
          config.sops.templates."adventurelog-db.env".path
        ];

        volumes = [
          "/var/lib/adventurelog/postgres:/var/lib/postgresql/data"
        ];

        extraOptions = [
          "--network=adventurelog"
        ];
      };

      adventureapi = {
        image = "ghcr.io/seanmorley15/adventurelog-backend:latest";
        pull = "always";

        dependsOn = [ "adventurelog-db" ];

        ports = [
          "127.0.0.1:${toString apiCfg.port}:8000"
        ];

        environment = {
          PUID = "1000";
          PGID = "1000";

          DJANGO_ADMIN_USERNAME = "zanbee";
          DJANGO_ADMIN_EMAIL = "adventurelog@openmailbox.nl";

          PGHOST = "adventurelog-db";

          # Legacy/split deployment variable names.
          PGDATABASE = "database";
          PGUSER = "adventure";

          # Current AdventureLog variable names.
          POSTGRES_DB = "database";
          POSTGRES_USER = "adventure";

          PUBLIC_URL = "https://adventureapi.fiordland-gar.ts.net";

          CSRF_TRUSTED_ORIGINS =
            "https://adventurelog.fiordland-gar.ts.net,https://adventureapi.fiordland-gar.ts.net";

          DEBUG = "False";

          FRONTEND_URL =
            "https://adventurelog.fiordland-gar.ts.net";

          BACKEND_PORT = toString apiCfg.port;
        };

        environmentFiles = [
          config.sops.templates."adventurelog-api.env".path
        ];

        volumes = [
          "/var/lib/adventurelog/media:/code/media"
        ];

        extraOptions = [
          "--network=adventurelog"
        ];
      };

      adventurelog = {
        image = "ghcr.io/seanmorley15/adventurelog-frontend:latest";
        pull = "always";

        dependsOn = [ "adventureapi" ];

        ports = [
          "127.0.0.1:${toString cfg.port}:3000"
        ];

        environment = {
          PUBLIC_SERVER_URL = "http://adventureapi:8000";
          ORIGIN = "https://adventurelog.fiordland-gar.ts.net";
          BODY_SIZE_LIMIT = "Infinity";

          FRONTEND_PORT = toString cfg.port;

          PUID = "1000";
          PGID = "1000";
        };

        extraOptions = [
          "--network=adventurelog"
        ];
      };
    };

    networking.firewall.allowedTCPPorts =
      lib.optionals cfg.openFirewall [ cfg.port ]
      ++ lib.optionals apiCfg.openFirewall [ apiCfg.port ];
  };
}
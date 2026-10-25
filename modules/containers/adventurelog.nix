
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
      requires = [
        "podman-network-adventurelog.service"
        "adventurelog-api-ready.service"
      ];
      after = [
        "podman-network-adventurelog.service"
        "adventurelog-api-ready.service"
      ];
    };

    systemd.services.podman-adventureapi = {
      requires = [
        "podman-network-adventurelog.service"
        "adventurelog-db-ready.service"
      ];
      after = [
        "podman-network-adventurelog.service"
        "adventurelog-db-ready.service"
      ];
    };

    systemd.services.podman-adventurelog-db = {
      requires = [ "podman-network-adventurelog.service" ];
      after = [ "podman-network-adventurelog.service" ];
    };

    # Compose equivalent:
    # depends_on:
    #   condition: service_healthy
    #
    # OCI dependsOn only controls start order.
    # These systemd services explicitly wait for container health.

    systemd.services.adventurelog-db-ready = {
      description = "Wait for AdventureLog PostGIS health";

      requires = [ "podman-adventurelog-db.service" ];
      after = [ "podman-adventurelog-db.service" ];

      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "150s";
      };

      script = ''
        for i in $(${pkgs.coreutils}/bin/seq 1 120); do
          status=$(${pkgs.podman}/bin/podman inspect adventurelog-db \
            --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}' 2>/dev/null || true)

          if [ "$status" = healthy ]; then
            exit 0
          fi

          ${pkgs.coreutils}/bin/sleep 1
        done

        echo "AdventureLog database did not become healthy" >&2
        exit 1
      '';
    };

    systemd.services.adventurelog-api-ready = {
      description = "Wait for AdventureLog backend health";

      requires = [ "podman-adventureapi.service" ];
      after = [ "podman-adventureapi.service" ];

      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "150s";
      };

      script = ''
        for i in $(${pkgs.coreutils}/bin/seq 1 120); do
          status=$(${pkgs.podman}/bin/podman inspect adventureapi \
            --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}' 2>/dev/null || true)

          if [ "$status" = healthy ]; then
            exit 0
          fi

          ${pkgs.coreutils}/bin/sleep 1
        done

        echo "AdventureLog backend did not become healthy" >&2
        exit 1
      '';
    };

    virtualisation.oci-containers.containers = {
      adventurelog-db = {
        image = "docker.io/postgis/postgis:16-3.5@sha256:94146ac37bc61e2322f88016056c5920729cb8c64c8542ed590af8fc2abdac07";
        pull = "missing";

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
          "--health-cmd=pg_isready -U adventure -d database"
          "--health-interval=5s"
          "--health-timeout=5s"
          "--health-retries=5"
          "--health-start-period=10s"
        ];
      };

      adventureapi = {
        # Upstream main build: 2026-10-24
        # Revision: 6b80516d5b9c5f675bbef56855bf4bdd711dbc45
        image = "ghcr.io/seanmorley15/adventurelog-backend:latest@sha256:22447c533ed843287f1b578e7624d551b2770a75c4eefc4b69b7cfb91b6d5586";
        pull = "missing";

        dependsOn = [ "adventurelog-db" ];

        ports = [
          "127.0.0.1:${toString apiCfg.port}:80"
        ];

        environment = {
          PUID = "1000";
          PGID = "1000";
          DJANGO_ADMIN_USERNAME = "zanbee";
          DJANGO_ADMIN_EMAIL = "adventurelog@openmailbox.nl";
          PGHOST = "adventurelog-db";
          PGDATABASE = "database";
          PGUSER = "adventure";
          POSTGRES_DB = "database";
          POSTGRES_USER = "adventure";
          PUBLIC_URL = "https://adventureapi.fiordland-gar.ts.net";
          CSRF_TRUSTED_ORIGINS =
            "https://adventurelog.fiordland-gar.ts.net,https://adventureapi.fiordland-gar.ts.net";
          DEBUG = "False";
          FRONTEND_URL = "https://adventurelog.fiordland-gar.ts.net";
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
          "--health-cmd=python -c \"import urllib.request; urllib.request.urlopen('http://localhost:80/health/')\""
          "--health-interval=15s"
          "--health-timeout=5s"
          "--health-retries=5"
          "--health-start-period=60s"
        ];
      };

      adventurelog = {
        # Upstream main build: 2026-10-24
        # Revision: 6b80516d5b9c5f675bbef56855bf4bdd711dbc45
        image = "ghcr.io/seanmorley15/adventurelog-frontend:latest@sha256:74e3972ecbd2a9708af4996f22acb6cca8e2fabe1c91d5fe60f6510d2ca490ec";
        pull = "missing";

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
          "--health-cmd=node -e \"fetch('http://127.0.0.1:3000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))\""
          "--health-interval=30s"
          "--health-timeout=5s"
          "--health-retries=5"
          "--health-start-period=30s"
        ];
      };
    };

    networking.firewall.allowedTCPPorts =
      lib.optionals cfg.openFirewall [ cfg.port ]
      ++ lib.optionals apiCfg.openFirewall [ apiCfg.port ];
  };
}

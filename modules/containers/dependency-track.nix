
{ config, lib, pkgs, ... }:

let
  cfg = config.apps.dependency-track;

  netUnit = "podman-network-dependency-track";
  postgresUnit = "podman-dependency-track-db";
  apiUnit = "podman-dependency-track-api";
  frontendUnit = "podman-dependency-track-frontend";
in
{
  options.apps.dependency-track = {
    enable = lib.mkEnableOption
      "Dependency-Track vulnerability and SBOM management";

    # Tailscale
    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Dependency-Track through Tailscale Services.";
    };

    tailscale.serviceName = lib.mkOption {
      type = lib.types.str;
      default = "dependency";
      description = "Tailscale service name.";
    };

    # Ports
    port = lib.mkOption {
      type = lib.types.port;
      default = 20280;
      description = "Local reverse proxy port for Tailscale Serve.";
    };

    apiPort = lib.mkOption {
      type = lib.types.port;
      default = 20282;
    };

    frontendPort = lib.mkOption {
      type = lib.types.port;
      default = 20281;
    };

    # URL
    url = lib.mkOption {
      type = lib.types.str;
      default = "https://dependency.fiordland-gar.ts.net";
      description = "Dependency-Track URL through Tailscale.";
    };

    # Container images
    apiImage = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/dependencytrack/apiserver:5.2.0";
    };

    frontendImage = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/dependencytrack/frontend:5.2.0";
    };

    postgresImage = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/library/postgres:18-alpine";
    };

    # Persistent storage
    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/dependency-track";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {

    # Podman
    virtualisation.oci-containers.backend = "podman";
    virtualisation.podman.enable = true;

    # SOPS
    sops.secrets."sif/dependency_track_db_password" = {};

    sops.templates."dependency-track-db.env".content = ''
      POSTGRES_PASSWORD=${config.sops.placeholder."sif/dependency_track_db_password"}
    '';

    sops.templates."dependency-track-api.env".content = ''
      DT_DATASOURCE_PASSWORD=${config.sops.placeholder."sif/dependency_track_db_password"}
    '';

    # Persistent directories
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root - -"
      "d ${cfg.dataDir}/postgres 0700 70 70 - -"
      "d ${cfg.dataDir}/api 0770 1000 1000 - -"
    ];

    # Podman network
    systemd.services.${netUnit} = {
      description = "Create Dependency-Track Podman network";

      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        ${pkgs.podman}/bin/podman network exists dependency-track \
          || ${pkgs.podman}/bin/podman network create dependency-track
      '';
    };

    # Service dependencies
    systemd.services.${postgresUnit} = {
      requires = [ "${netUnit}.service" ];
      after = [ "${netUnit}.service" ];
    };

    systemd.services.${apiUnit} = {
      requires = [
        "${netUnit}.service"
        "${postgresUnit}.service"
      ];

      after = [
        "${netUnit}.service"
        "${postgresUnit}.service"
      ];
    };

    systemd.services.${frontendUnit} = {
      requires = [ "${netUnit}.service" ];
      after = [ "${netUnit}.service" ];
    };

    # Containers
    virtualisation.oci-containers.containers = {

      # PostgreSQL
      dependency-track-db = {
        image = cfg.postgresImage;
        autoStart = true;

        environment = {
          POSTGRES_DB = "dtrack";
          POSTGRES_USER = "dtrack";
        };

        environmentFiles = [
          config.sops.templates."dependency-track-db.env".path
        ];

        volumes = [
          "${cfg.dataDir}/postgres:/var/lib/postgresql"
        ];

        extraOptions = [
          "--network=dependency-track"
          "--user=70:70"
        ];
      };

      # Dependency-Track API
      dependency-track-api = {
        image = cfg.apiImage;
        autoStart = true;

        dependsOn = [
          "dependency-track-db"
        ];

        environment = {
          DT_DATASOURCE_URL =
            "jdbc:postgresql://dependency-track-db:5432/dtrack";

          DT_DATASOURCE_USERNAME = "dtrack";
        };

        environmentFiles = [
          config.sops.templates."dependency-track-api.env".path
        ];

        volumes = [
          "${cfg.dataDir}/api:/data"
        ];

        ports = [
          "127.0.0.1:${toString cfg.apiPort}:8080"
        ];

        extraOptions = [
          "--network=dependency-track"
          "--memory=2g"
        ];
      };

      # Dependency-Track frontend
      dependency-track-frontend = {
        image = cfg.frontendImage;
        autoStart = true;

        environment = {
          API_BASE_URL = cfg.url;
        };

        ports = [
          "127.0.0.1:${toString cfg.frontendPort}:8080"
        ];

        extraOptions = [
          "--network=dependency-track"
        ];
      };
    };

    # Nginx reverse proxy
    services.nginx.enable = true;

    services.nginx.virtualHosts."dependency-track-local" = {
      listen = [
        {
          addr = "127.0.0.1";
          port = cfg.port;
        }
      ];

      locations."/api/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.apiPort}";
      };

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.frontendPort}";
      };
    };

    # Firewall
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}

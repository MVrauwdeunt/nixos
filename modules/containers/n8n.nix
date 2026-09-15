cat > modules/containers/n8n.nix <<'EOF'
{ config, lib, pkgs, ... }:

let
  cfg = config.apps.n8n;
in
{
  options.apps.n8n = {
    enable = lib.mkEnableOption "n8n";

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/n8nio/n8n@sha256:a8c95f75c6fdf65f5f2b7a7b354744eaa1c62bb911b5c00af6499c3f38e4cd32";
      description = "n8n container image.";
    };

    postgresImage = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/library/postgres@sha256:cf78e76683b9ca8c5733cbbdce6c9262b45b6767934dd0a95e671f9a0fc20685";
      description = "PostgreSQL container image.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/n8n";
      description = "Base data directory for n8n.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5678;
      description = "Local n8n web port.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the n8n port in the firewall.";
    };

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose n8n through Tailscale Services.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";

    sops.secrets."sif/n8n_db_password" = {};

    sops.templates."n8n-db.env".content = ''
      POSTGRES_PASSWORD=${config.sops.placeholder."sif/n8n_db_password"}
    '';

    sops.templates."n8n.env".content = ''
      DB_POSTGRESDB_PASSWORD=${config.sops.placeholder."sif/n8n_db_password"}
    '';

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
      "d ${cfg.dataDir}/postgres 0755 root root -"
      "d ${cfg.dataDir}/storage 0755 1000 1000 -"
      "d ${cfg.dataDir}/files 0755 1000 1000 -"
    ];

    systemd.services.podman-network-n8n = {
      description = "Create n8n Podman network";
      wantedBy = [ "multi-user.target" ];

      before = [
        "podman-n8n.service"
        "podman-n8n-db.service"
      ];

      serviceConfig.Type = "oneshot";

      script = ''
        ${pkgs.podman}/bin/podman network exists n8n \
          || ${pkgs.podman}/bin/podman network create n8n
      '';
    };

    systemd.services.podman-n8n-db = {
      requires = [ "podman-network-n8n.service" ];
      after = [ "podman-network-n8n.service" ];
    };

    systemd.services.podman-n8n = {
      requires = [
        "podman-network-n8n.service"
        "podman-n8n-db.service"
      ];

      after = [
        "podman-network-n8n.service"
        "podman-n8n-db.service"
      ];
    };

    virtualisation.oci-containers.containers = {
      n8n-db = {
        image = cfg.postgresImage;

        environment = {
          POSTGRES_USER = "n8n";
          POSTGRES_DB = "n8n";
          TZ = "Etc/UTC";
        };

        environmentFiles = [
          config.sops.templates."n8n-db.env".path
        ];

        volumes = [
          "${cfg.dataDir}/postgres:/var/lib/postgresql/data"
        ];

        extraOptions = [
          "--network=n8n"
        ];
      };

      n8n = {
        image = cfg.image;

        dependsOn = [ "n8n-db" ];

        ports = [
          "127.0.0.1:${toString cfg.port}:5678"
        ];

        environment = {
          DB_TYPE = "postgresdb";
          DB_POSTGRESDB_HOST = "n8n-db";
          DB_POSTGRESDB_PORT = "5432";
          DB_POSTGRESDB_DATABASE = "n8n";
          DB_POSTGRESDB_USER = "n8n";

          NODE_ENV = "production";
          NODE_FUNCTION_ALLOW_BUILTIN = "*";

          TZ = "Etc/UTC";

          WEBHOOK_URL = "https://n8n.fiordland-gar.ts.net/";
        };

        environmentFiles = [
          config.sops.templates."n8n.env".path
        ];

        volumes = [
          "${cfg.dataDir}/storage:/home/node/.n8n"
          "${cfg.dataDir}/files:/files"
        ];

        extraOptions = [
          "--network=n8n"
        ];
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
EOF
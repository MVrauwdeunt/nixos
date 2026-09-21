{ config, lib, pkgs, ... }:

let
  cfg = config.apps.homelable;

  proxmoxEnv = lib.optionalString cfg.proxmox.enable ''
    PROXMOX_TOKEN_ID=${config.sops.placeholder."sif/homelable_proxmox_token_id"}
    PROXMOX_TOKEN_SECRET=${config.sops.placeholder."sif/homelable_proxmox_token_secret"}
  '';
in
{
  options.apps.homelable = {
    enable = lib.mkEnableOption "Homelable";

    backendImage = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/pouzor/homelable-backend:latest";
      description = "Container image for the Homelable backend.";
    };

    frontendImage = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/pouzor/homelable-frontend:latest";
      description = "Container image for the Homelable frontend.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/homelable";
      description = "Persistent data directory for Homelable.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3001;
      description = "Local Homelable web port. 3001 avoids Sif's Forgejo port 3000.";
    };

    url = lib.mkOption {
      type = lib.types.str;
      default = "https://homelable.fiordland-gar.ts.net";
      description = "Browser origin used for Homelable CORS configuration.";
    };

    authUsername = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Local Homelable login username.";
    };

    scannerRanges = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "192.168.100.0/24"
        "192.168.178.0/24"
      ];
      description = "CIDR ranges Homelable may scan.";
    };

    statusCheckerInterval = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "Node status check interval in seconds.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the Homelable web port in the host firewall.";
    };

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Homelable through Tailscale Services.";
    };

    proxmox = {
      enable = lib.mkEnableOption "Homelable Proxmox auto-sync";

      host = lib.mkOption {
        type = lib.types.str;
        default = "hvergelmir";
        description = "Proxmox host name or IP address.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8006;
        description = "Proxmox API port.";
      };

      verifyTLS = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Verify the Proxmox HTTPS certificate.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";
    virtualisation.podman.enable = true;

    sops.secrets = {
      "sif/homelable_secret_key" = {};
      "sif/homelable_password_hash" = {};
    } // lib.optionalAttrs cfg.proxmox.enable {
      "sif/homelable_proxmox_token_id" = {};
      "sif/homelable_proxmox_token_secret" = {};
    };

    sops.templates."homelable.env".content = ''
      SECRET_KEY=${config.sops.placeholder."sif/homelable_secret_key"}
      AUTH_PASSWORD_HASH='${config.sops.placeholder."sif/homelable_password_hash"}'
    '' + proxmoxEnv;

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root - -"
    ];

    systemd.services.homelable-network = {
      description = "Create Homelable Podman network";
      wantedBy = [ "multi-user.target" ];

      before = [
        "podman-homelable-backend.service"
        "podman-homelable.service"
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        ${pkgs.podman}/bin/podman network exists homelable \
          || ${pkgs.podman}/bin/podman network create homelable
      '';
    };

    systemd.services.podman-homelable-backend = {
      requires = [ "homelable-network.service" ];
      after = [
        "network-online.target"
        "homelable-network.service"
      ];
      wants = [ "network-online.target" ];
    };

    systemd.services.podman-homelable = {
      requires = [
        "homelable-network.service"
        "podman-homelable-backend.service"
      ];
      after = [
        "network-online.target"
        "homelable-network.service"
        "podman-homelable-backend.service"
      ];
      wants = [ "network-online.target" ];
    };

    virtualisation.oci-containers.containers = {
      homelable-backend = {
        image = cfg.backendImage;
        pull = "always";

        environment = {
          SQLITE_PATH = "/app/data/homelab.db";
          CORS_ORIGINS = builtins.toJSON [ cfg.url ];
          AUTH_MODE = "local";
          AUTH_USERNAME = cfg.authUsername;
          SCANNER_RANGES = builtins.toJSON cfg.scannerRanges;
          STATUS_CHECKER_INTERVAL = toString cfg.statusCheckerInterval;
        } // lib.optionalAttrs cfg.proxmox.enable {
          PROXMOX_HOST = cfg.proxmox.host;
          PROXMOX_PORT = toString cfg.proxmox.port;
          PROXMOX_VERIFY_TLS = if cfg.proxmox.verifyTLS then "true" else "false";
        };

        environmentFiles = [
          config.sops.templates."homelable.env".path
        ];

        volumes = [
          "${cfg.dataDir}:/app/data"
        ];

        extraOptions = [
          "--network=homelable"
          "--network-alias=backend"
          "--cap-add=NET_RAW"
          "--security-opt=no-new-privileges"
        ];
      };

      # Keep this container named exactly "homelable": tailscale-services.nix
      # waits for podman-homelable.service for apps.homelable.
      homelable = {
        image = cfg.frontendImage;
        pull = "always";

        dependsOn = [
          "homelable-backend"
        ];

        ports = [
          "127.0.0.1:${toString cfg.port}:80"
        ];

        extraOptions = [
          "--network=homelable"
        ];
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
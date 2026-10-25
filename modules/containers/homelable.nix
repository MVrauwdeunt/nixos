{ config, lib, pkgs, ... }:
let
  cfg = config.apps.homelable;
  proxmoxEnv = lib.optionalString cfg.proxmox.enable ''
    PROXMOX_TOKEN_ID=${config.sops.placeholder."sif/homelable_proxmox_token_id"}
    PROXMOX_TOKEN_SECRET=${config.sops.placeholder."sif/homelable_proxmox_token_secret"}
  '';

  generateScannerEnv = pkgs.writeShellScript "homelable-generate-scanner-env" ''
    set -euo pipefail
    ${pkgs.coreutils}/bin/mkdir -p /run/homelable
    static_ranges='${builtins.toJSON cfg.scannerRanges}'
    tailscale_ranges='[]'
    if status_json="$(${pkgs.tailscale}/bin/tailscale status --json 2>/dev/null)"; then
      tailscale_ranges="$(
        printf '%s' "$status_json" |
          ${pkgs.jq}/bin/jq -c '
            [ .Self.TailscaleIPs[]?, (.Peer[]?.TailscaleIPs[]?) ]
            | map(select(startswith("100.")))
            | map(. + "/32")
            | unique
          '
      )"
    else
      echo "Warning: unable to read Tailscale status; using static scanner ranges only."
    fi
    combined="$(
      ${pkgs.jq}/bin/jq -cn \
        --argjson static "$static_ranges" \
        --argjson tailscale "$tailscale_ranges" \
        '$static + $tailscale | unique'
    )"
    printf 'SCANNER_RANGES=%s\n' "$combined" > /run/homelable/scanner.env
    echo "Generated Homelable scanner ranges:"
    echo "$combined" | ${pkgs.jq}/bin/jq .
  '';
in
{
  options.apps.homelable = {
    enable = lib.mkEnableOption "Homelable";

    backendImage = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/pouzor/homelable-backend:3.6.0@sha256:1e501424e8c53989fcea1dc9311d46614ae159b2bfee4608a5c0cd5baee3e9dc";
      description = "Container image for the Homelable backend.";
    };

    frontendImage = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/pouzor/homelable-frontend:3.6.0@sha256:5950f4905da2ea92b2a3870066399e718987a4a23d16c368935b9ddb7901635a";
      description = "Container image for the Homelable frontend.";
    };

    mcp = {
      enable = lib.mkEnableOption "Homelable MCP server";
      image = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/pouzor/homelable-mcp:3.6.0@sha256:42838c0733b6443bcb6aaa3310f39daa8e700817ddb1f4466ff58d5cc0013c85";
        description = "Homelable MCP container image.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 8001;
        description = "Host port for Homelable MCP.";
      };
      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
        description = "Bind address for the Homelable MCP server.";
      };
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open the MCP port in the firewall.";
      };
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
        "192.168.30.0/24"
        "192.168.100.0/24"
        "192.168.178.0/24"
      ];
      description = ''
        Static CIDR ranges Homelable may scan.
        Current Tailscale IPv4 peers are automatically added as /32 ranges.
      '';
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
    }
    // lib.optionalAttrs cfg.proxmox.enable {
      "sif/homelable_proxmox_token_id" = {};
      "sif/homelable_proxmox_token_secret" = {};
    }
    // lib.optionalAttrs cfg.mcp.enable {
      "sif/homelable_mcp_api_key" = {};
      "sif/homelable_mcp_service_key" = {};
    };

    sops.templates."homelable.env".content = ''
      SECRET_KEY=${config.sops.placeholder."sif/homelable_secret_key"}
      AUTH_PASSWORD_HASH='${config.sops.placeholder."sif/homelable_password_hash"}'
    ''
    + proxmoxEnv
    + lib.optionalString cfg.mcp.enable ''
      MCP_SERVICE_KEY=${config.sops.placeholder."sif/homelable_mcp_service_key"}
    '';

    sops.templates."homelable-mcp.env" = lib.mkIf cfg.mcp.enable {
      content = ''
        MCP_API_KEY=${config.sops.placeholder."sif/homelable_mcp_api_key"}
        MCP_SERVICE_KEY=${config.sops.placeholder."sif/homelable_mcp_service_key"}
      '';
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root - -"
    ];

    systemd.services.homelable-network = {
      description = "Create Homelable Podman network";
      wantedBy = [ "multi-user.target" ];
      before = [
        "podman-homelable-backend.service"
        "podman-homelable.service"
      ] ++ lib.optionals cfg.mcp.enable [
        "podman-homelable-mcp.service"
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
        "tailscaled.service"
        "homelable-network.service"
      ];
      wants = [ "network-online.target" "tailscaled.service" ];
      serviceConfig.ExecStartPre = [ "${generateScannerEnv}" ];
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

    systemd.services.podman-homelable-mcp = lib.mkIf cfg.mcp.enable {
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
        pull = "missing";
        environment = {
          SQLITE_PATH = "/app/data/homelab.db";
          CORS_ORIGINS = builtins.toJSON [ cfg.url ];
          AUTH_MODE = "local";
          AUTH_USERNAME = cfg.authUsername;
          STATUS_CHECKER_INTERVAL = toString cfg.statusCheckerInterval;
        } // lib.optionalAttrs cfg.proxmox.enable {
          PROXMOX_HOST = cfg.proxmox.host;
          PROXMOX_PORT = toString cfg.proxmox.port;
          PROXMOX_VERIFY_TLS =
            if cfg.proxmox.verifyTLS then "true" else "false";
        };
        environmentFiles = [
          config.sops.templates."homelable.env".path
          "/run/homelable/scanner.env"
        ];
        volumes = [ "${cfg.dataDir}:/app/data" ];
        extraOptions = [
          "--network=homelable"
          "--network-alias=backend"
          "--cap-add=NET_RAW"
          "--security-opt=no-new-privileges"
        ];
      };

      homelable = {
        image = cfg.frontendImage;
        pull = "missing";
        dependsOn = [ "homelable-backend" ];
        ports = [ "127.0.0.1:${toString cfg.port}:80" ];
        extraOptions = [ "--network=homelable" ];
      };
    } // lib.optionalAttrs cfg.mcp.enable {
      homelable-mcp = {
        image = cfg.mcp.image;
        pull = "missing";
        dependsOn = [ "homelable-backend" ];
        environment = { BACKEND_URL = "http://backend:8000"; };
        environmentFiles = [
          config.sops.templates."homelable-mcp.env".path
        ];
        ports = [
          "${cfg.mcp.listenAddress}:${toString cfg.mcp.port}:8001"
        ];
        extraOptions = [
          "--network=homelable"
          "--security-opt=no-new-privileges"
        ];
      };
    };

    networking.firewall.allowedTCPPorts =
      lib.optionals cfg.openFirewall [ cfg.port ]
      ++ lib.optionals (cfg.mcp.enable && cfg.mcp.openFirewall)
        [ cfg.mcp.port ];
  };
}
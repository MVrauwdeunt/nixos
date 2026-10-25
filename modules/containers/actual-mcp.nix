
{ config, lib, ... }:

let
  cfg = config.apps.actual-mcp;
in
{
  options.apps.actual-mcp = {
    enable = lib.mkEnableOption
      "read-only Actual Budget MCP server";

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/sstefanov/actual-mcp:v1.14.0";
      description = "Actual MCP container image.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/actual-mcp";
      description = "Separate local Actual MCP cache.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3101;
      description = "MCP HTTP port.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open MCP port on LAN/WAN interfaces.";
    };
  };

  config = lib.mkIf cfg.enable {

    # Existing Actual Budget passwords are declared
    # by actual-bunq-importer.nix.
    # Only the MCP bearer token is new.
    sops.secrets."saga/actual_mcp_bearer_token" = {
      sopsFile = ../../secrets.yaml;
    };

    # Generate environment file securely through SOPS.
    sops.templates."actual-mcp.env" = {
      mode = "0400";

      content = ''
        ACTUAL_SERVER_URL=http://127.0.0.1:5006
        ACTUAL_PASSWORD=${config.sops.placeholder."saga/actual_budget_password"}
        ACTUAL_BUDGET_ENCRYPTION_PASSWORD=${config.sops.placeholder."saga/actual_budget_encryption_password"}
        BEARER_TOKEN=${config.sops.placeholder."saga/actual_mcp_bearer_token"}
        ACTUAL_DATA_DIR=/data
        ACTUAL_SYNC_TTL_MS=60000
      '';
    };

    # Separate data directory for MCP.
    # No direct access to Actual Budget database.
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0700 root root -"
    ];

    # Podman container
    virtualisation.oci-containers.containers.actual-mcp = {
      image = cfg.image;
      pull = "missing";
      autoStart = true;

      environmentFiles = [
        config.sops.templates."actual-mcp.env".path
      ];

      volumes = [
        "${cfg.dataDir}:/data"
      ];

      # Host networking is required because Actual Budget
      # listens on 127.0.0.1:5006 on Saga.
      extraOptions = [
        "--network=host"
        "--security-opt=no-new-privileges"
      ];

      # Streamable HTTP transport with bearer authentication.
      # Write access is deliberately disabled.
      cmd = [
        "--sse"
        "--enable-bearer"
        "--port"
        (toString cfg.port)
      ];
    };

    # Start MCP after Actual Budget.
    systemd.services.podman-actual-mcp = {
      requires = [
        "podman-actual-budget.service"
      ];

      after = [
        "podman-actual-budget.service"
      ];
    };

    # Only expose MCP through Tailscale by default.
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      cfg.port
    ];

    # Optional LAN/WAN access.
    # Disabled by default and by hosts/saga/apps.nix.
    networking.firewall.allowedTCPPorts =
      lib.optionals cfg.openFirewall [ cfg.port ];
  };
}


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
      default = "docker.io/sstefanov/actual-mcp:v1.15.1";
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
    #
    # MCP bearer token and actual budget Sync ID.
    sops.secrets = {
      "saga/actual_mcp_bearer_token" = {
        sopsFile = ../../secrets.yaml;
      };

      "saga/actual_budget_sync_id" = {
        sopsFile = ../../secrets.yaml;
      };
    };

    # Generate environment securely through SOPS.
    sops.templates."actual-mcp.env" = {
      mode = "0400";

      content = ''
        ACTUAL_SERVER_URL=http://127.0.0.1:5006
        ACTUAL_PASSWORD=${config.sops.placeholder."saga/actual_budget_password"}
        ACTUAL_BUDGET_SYNC_ID=${config.sops.placeholder."saga/actual_budget_sync_id"}
        ACTUAL_BUDGET_ENCRYPTION_PASSWORD=${config.sops.placeholder."saga/actual_budget_encryption_password"}
        BEARER_TOKEN=${config.sops.placeholder."saga/actual_mcp_bearer_token"}
        ACTUAL_DATA_DIR=/data
        ACTUAL_SYNC_TTL_MS=60000
      '';
    };

    # Persistent cache separate from Actual Budget.
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0700 root root -"
    ];

    # Actual MCP Podman container.
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

      # Host networking because Actual Budget
      # listens on Saga localhost:5006.
      extraOptions = [
        "--network=host"
        "--security-opt=no-new-privileges"
      ];

      # Streamable HTTP with bearer authentication.
      # No --enable-write: MCP remains read-only.
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

    # Allow MCP traffic via Tailscale.
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      cfg.port
    ];

    # Optional access through other interfaces.
    # Disabled by default.
    networking.firewall.allowedTCPPorts =
      lib.optionals cfg.openFirewall [ cfg.port ];
  };
}

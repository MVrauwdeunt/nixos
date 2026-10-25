
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
      description = "Separate local MCP budget cache.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3001;
      description = "MCP HTTP port over Tailscale.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Actual passwords are already declared by
    # modules/containers/actual-bunq-importer.nix.
    sops.secrets."saga/actual_mcp_bearer_token".sopsFile =
      ../../secrets.yaml;

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

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0700 root root -"
    ];

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

      # Actual Budget listens on Saga localhost only.
      extraOptions = [
        "--network=host"
        "--security-opt=no-new-privileges"
      ];

      # Read-only: deliberately no --enable-write.
      cmd = [
        "--sse"
        "--enable-bearer"
        "--port"
        (toString cfg.port)
      ];
    };

    systemd.services.podman-actual-mcp = {
      requires = [ "podman-actual-budget.service" ];
      after = [ "podman-actual-budget.service" ];
    };

    # Only allow MCP through Tailscale.
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      cfg.port
    ];
  };
}

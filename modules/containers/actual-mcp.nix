
{ config, lib, ... }:

let
  cfg = config.apps.actual-mcp;

  defaultImage = "docker.io/sstefanov/actual-mcp:v1.15.1";
in
{
  imports = [
    (import ./common.nix {
      name = "actual-mcp";
      image = defaultImage;

      port = 3101;

      # Host networking: geen Podman port publishing.
      publishedPorts = [ ];
      bridgeNetwork = false;

      dataDir = "/var/lib/actual-mcp";
      configMount = "/data";

      directoryMode = "0700";
      directoryOwner = "root";
      directoryGroup = "root";

      # Behoud de oorspronkelijke environment en healthcheck.
      useTimezone = false;
      usePuidPgid = false;
      disableHealthcheck = false;

      extraOptions = [
        "--network=host"
        "--security-opt=no-new-privileges"
      ];
    })
  ];

  options.apps.actual-mcp.image = lib.mkOption {
    type = lib.types.str;
    default = defaultImage;
    description = "Actual MCP container image.";
  };

  config = lib.mkIf cfg.enable {
    # Existing Actual Budget passwords are declared
    # by actual-bunq-importer.nix.
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

    virtualisation.oci-containers.containers.actual-mcp = {
      image = lib.mkForce cfg.image;

      environmentFiles = [
        config.sops.templates."actual-mcp.env".path
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
  };
}

{ config, lib, ... }:

let
  cfg = config.apps.allos-mcp;

  images = { default = "ghcr.io/mvrauwdeunt/allos-mcp:0.2.2@sha256:0fc702883457b41a56991b89e552d73dad0dd8e290db68e5caae175cd12b20d5"; };
in
{
  imports = [
    (import ./common.nix {
      name = "allos-mcp";
      image = images.default;

      port = 8765;
      containerPort = 8765;
      bindAddress = cfg.listenAddress;

      mountConfig = false;
      createDataDir = false;

      useTimezone = false;
      usePuidPgid = false;
      bridgeNetwork = false;
      disableHealthcheck = true;
      tailscaleDefault = false;

      environment = {
        ALLOS_DB_PATH = "/data/allos.db";
        ALLOS_MCP_ALLOWED_HOSTS = "saga.fiordland-gar.ts.net:8765";
        ALLOS_PROFILE_ID = toString cfg.profileId;

        ALLOS_MCP_AUTH_TOKEN_FILE = "/run/secrets/token";
        ALLOS_MCP_TLS_CERT_FILE = "/run/secrets/server.crt";
        ALLOS_MCP_TLS_KEY_FILE = "/run/secrets/server.key";

        HOME = "/tmp";
        TMPDIR = "/tmp";
      };

      extraVolumes = [
        "${config.apps.allos.dataDir}:/data:ro"
        "${config.sops.secrets."saga/allos_mcp_token".path}:/run/secrets/token:ro"
        "${config.sops.secrets."saga/allos_mcp_tls_cert".path}:/run/secrets/server.crt:ro"
        "${config.sops.secrets."saga/allos_mcp_tls_key".path}:/run/secrets/server.key:ro"
      ];

      extraOptions = [
        "--user=1000:1000"
        "--security-opt=no-new-privileges"
        "--cap-drop=ALL"
        "--read-only"
        "--tmpfs=/tmp:rw,nosuid,nodev,size=16m"
      ];
    })
  ];

  options.apps.allos-mcp = {
    image = lib.mkOption {
      type = lib.types.str;
      default = images.default;
      description = "Allos MCP container image.";
    };

    profileId = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
      description = "Authorized Allos profile ID.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Allos MCP bind address.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets = lib.genAttrs [
      "saga/allos_mcp_token"
      "saga/allos_mcp_tls_cert"
      "saga/allos_mcp_tls_key"
    ] (_: {
      sopsFile = ../../secrets.yaml;
      uid = 1000;
      gid = 1000;
      mode = "0400";
      restartUnits = [ "podman-allos-mcp.service" ];
    });

    virtualisation.oci-containers.containers.allos-mcp = {
      image = lib.mkForce cfg.image;

      cmd = [
        "--transport"
        "http"
        "--host"
        "0.0.0.0"
        "--port"
        "8765"
        "--allow-nonloopback"
      ];
    };

    systemd.services.podman-allos-mcp = {
      requires = [ "podman-allos.service" ];
      after = [
        "podman-allos.service"
        "tailscaled.service"
      ];
      wants = [ "tailscaled.service" ];
    };

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      cfg.port
    ];
  };
}

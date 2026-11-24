
# modules/containers/allos-mcp.nix
#
# Read-only MCP server for Allos health data.
# Accessible directly through Saga's Tailscale IP.
# No Tailscale Serve service required.

{ config, lib, pkgs, ... }:

let
  cfg = config.apps.allos-mcp;

  python = pkgs.python3.withPackages (ps: [
    ps.mcp
  ]);

  source = pkgs.runCommand "allos-mcp-source" {} ''
    mkdir -p $out/app
    cp ${./allos-mcp/server.py} $out/app/server.py
    cp ${./allos-mcp/db.py} $out/app/db.py
  '';

  image = pkgs.dockerTools.buildLayeredImage {
    name = "allos-mcp";
    tag = "0.2.3";

    contents = [
      python
      source
      pkgs.cacert
    ];

    config = {
      WorkingDir = "/app";

      Cmd = [
        "${python}/bin/python3"
        "${source}/app/server.py"
      ];
    };
  };
in
{
  imports = [
    (import ./common.nix {
      name = "allos-mcp";
      image = "allos-mcp:0.2.3";

      port = 8765;
      containerPort = 8765;

      # Bind exclusively to Saga's Tailscale IPv4 address.
      bindAddress = cfg.listenAddress;

      mountConfig = false;
      createDataDir = false;

      useTimezone = false;
      usePuidPgid = false;
      bridgeNetwork = false;

      disableHealthcheck = true;

      # No dedicated Tailscale Service.
      tailscaleDefault = false;

      environment = {
        ALLOS_DB_PATH = "/data/allos.db";
        ALLOS_PROFILE_ID = toString cfg.profileId;
      };

      # Include SQLite WAL and SHM files.
      extraVolumes = [
        "${config.apps.allos.dataDir}:/data:ro"
      ];

      extraOptions = [
        # Match the Allos database owner.
        "--user=1000:1000"

        # Container hardening.
        "--security-opt=no-new-privileges"
        "--cap-drop=ALL"
        "--read-only"

        # Temporary runtime storage.
        "--tmpfs=/tmp:rw,nosuid,nodev,size=16m"
      ];
    })
  ];

  options.apps.allos-mcp = {
    profileId = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
      description = "Authorized Allos profile ID.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Saga Tailscale IPv4 address.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.listenAddress != "127.0.0.1";
        message = "Set apps.allos-mcp.listenAddress to Saga's Tailscale IPv4 address.";
      }
      {
        assertion = !cfg.tailscale.enable;
        message = "Allos MCP must not use a separate Tailscale Service.";
      }
    ];

    virtualisation.oci-containers.containers.allos-mcp = {
      imageFile = image;
    };

    systemd.services.podman-allos-mcp = {
      requires = [ "podman-allos.service" ];
      after = [
        "podman-allos.service"
        "tailscaled.service"
      ];
      wants = [ "tailscaled.service" ];
    };
  };
}

{ config, lib, ... }:

let
  cfg = config.apps.garmin-bridge;
in
{
  options.apps.garmin-bridge = {
    enable = lib.mkEnableOption "Garmin Connect bridge";

    image = lib.mkOption {
      type = lib.types.str;
      default = "localhost/garmin-bridge:test";
      description = "Garmin Bridge OCI image";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/garmin-bridge";
      description = "Persistent Garmin Bridge data directory";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8765;
      description = "Local Garmin Bridge API port";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open Garmin Bridge port in firewall";
    };

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Expose Garmin Bridge through Tailscale";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0700 root root -"
      "d ${cfg.dataDir}/tokens 0700 root root -"
    ];

    virtualisation.oci-containers.containers.garmin-bridge = {
      image = cfg.image;

      # Image is built locally for now.
      pull = "never";

      autoStart = true;

      ports = [
        "127.0.0.1:${toString cfg.port}:8765"
      ];

      volumes = [
        "${cfg.dataDir}/tokens:/data/tokens"
      ];

      extraOptions = [
        "--network=n8n"
        "--security-opt=no-new-privileges"
      ];
    };

    # n8n.nix creates this Podman network.
    systemd.services.podman-garmin-bridge = {
      requires = [
        "podman-network-n8n.service"
      ];

      after = [
        "network-online.target"
        "podman-network-n8n.service"
      ];

      wants = [
        "network-online.target"
      ];
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}

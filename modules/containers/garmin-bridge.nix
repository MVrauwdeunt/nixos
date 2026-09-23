{ config, lib, pkgs, ... }:

let
  cfg = config.apps.garmin-bridge;

  source = ./garmin-bridge;

  sourceHash = builtins.substring 0 12 (
    builtins.hashString "sha256" (
      builtins.readFile ./garmin-bridge/app.py
      + builtins.readFile ./garmin-bridge/requirements.txt
      + builtins.readFile ./garmin-bridge/Containerfile
    )
  );

  image = "localhost/garmin-bridge:${sourceHash}";
in
{
  options.apps.garmin-bridge = {
    enable = lib.mkEnableOption "Garmin Connect bridge";

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
    };

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0700 root root -"
      "d ${cfg.dataDir}/tokens 0700 root root -"
    ];

    systemd.services.garmin-bridge-image = {
      description = "Build Garmin Bridge OCI image";

      wantedBy = [ "multi-user.target" ];

      before = [
        "podman-garmin-bridge.service"
      ];

      after = [
        "network-online.target"
      ];

      wants = [
        "network-online.target"
      ];

      path = [
        pkgs.podman
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        if ! podman image exists ${image}; then
          echo "Building ${image}"

          podman build \
            --tag ${image} \
            --file ${source}/Containerfile \
            ${source}
        else
          echo "${image} already exists"
        fi
      '';
    };

    virtualisation.oci-containers.containers.garmin-bridge = {
      image = image;
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

    systemd.services.podman-garmin-bridge = {
      requires = [
        "garmin-bridge-image.service"
        "podman-network-n8n.service"
      ];

      after = [
        "garmin-bridge-image.service"
        "podman-network-n8n.service"
        "network-online.target"
      ];
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
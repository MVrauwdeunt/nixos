{ config, lib, pkgs, ... }:
let
  cfg = config.apps.garmin-bridge;
  source = ./garmin-bridge;
  sourceHash = builtins.substring 0 12 (builtins.hashString "sha256" (
    builtins.readFile ./garmin-bridge/app.py
    + builtins.readFile ./garmin-bridge/requirements.txt
    + builtins.readFile ./garmin-bridge/Containerfile
  ));
  image = "localhost/garmin-bridge:${sourceHash}";
in {
  imports = [ (import ./common.nix {
    name = "garmin-bridge";
    inherit image;
    port = 8765;
    dataDir = "/var/lib/garmin-bridge";
    mountConfig = false;
    directoryMode = "0700";
    directoryOwner = "root";
    directoryGroup = "root";
    useTimezone = false;
    usePuidPgid = false;
    bridgeNetwork = false;
    disableHealthcheck = false;
    extraVolumes = [ "${cfg.dataDir}/tokens:/data/tokens" ];
    extraOptions = [ "--network=n8n" "--security-opt=no-new-privileges" ];
  }) ];

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";
    virtualisation.oci-containers.containers.garmin-bridge = {
      pull = lib.mkForce "never";
      autoStart = true;
    };
    systemd.tmpfiles.rules = [ "d ${cfg.dataDir}/tokens 0700 root root -" ];
    systemd.services.garmin-bridge-image = {
      description = "Build Garmin Bridge OCI image";
      wantedBy = [ "multi-user.target" ];
      before = [ "podman-garmin-bridge.service" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = [ pkgs.podman ];
      serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
      script = ''
        if ! podman image exists ${image}; then
          echo "Building ${image}"
          podman build --tag ${image} --file ${source}/Containerfile ${source}
        else
          echo "${image} already exists"
        fi
      '';
    };
    systemd.services.podman-garmin-bridge = {
      requires = [ "garmin-bridge-image.service" "podman-network-n8n.service" ];
      after = [ "garmin-bridge-image.service" "podman-network-n8n.service" "network-online.target" ];
    };
  };
}

{ config, lib, ... }:
let cfg = config.apps.beszel;
in {
  imports = [ (import ./common.nix {
    name = "beszel";
    image = cfg.image;
    port = 8090;
    dataDir = "/var/lib/beszel";
    tailscaleDefault = true;
    mountConfig = false;
    directoryOwner = "root";
    directoryGroup = "root";
    useTimezone = false;
    usePuidPgid = false;
    bridgeNetwork = false;
    disableHealthcheck = false;
    extraVolumes = [ "${cfg.dataDir}/hub:/beszel_data" ];
    environment.APP_URL = cfg.appUrl;
    extraOptions = [ "--hostname=beszel" "--userns=host" ];
  }) ];

  options.apps.beszel = {
    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/henrygd/beszel:0.21.1@sha256:8514a69d9bbbcb74f371a3205561ee231fc0289739cea64e8131f341d695b770";
    };
    appUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://beszel.fiordland-gar.ts.net";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";
    virtualisation.oci-containers.containers.beszel.autoStart = true;
    systemd.tmpfiles.rules = [ "d ${cfg.dataDir}/hub 0755 root root - -" ];
    systemd.services.podman-beszel = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
    };
  };
}

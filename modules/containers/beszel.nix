{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.apps.beszel;
in
{
  options.apps.beszel = {
    enable = mkEnableOption "Beszel hub container stack";

    image = mkOption {
      type = types.str;
      default = "docker.io/henrygd/beszel:latest";
      description = "Container image for the Beszel hub";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/beszel";
      description = "Base data directory for Beszel";
    };

    appPort = mkOption {
      type = types.port;
      default = 8090;
      description = "Internal port used by the Beszel hub";
    };

    appUrl = mkOption {
      type = types.str;
      default = "https://beszel.fiordland-gar.ts.net";
      description = "Public URL advertised by the Beszel hub";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the Beszel port on the host firewall";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root - -"
      "d ${cfg.dataDir}/hub 0755 root root - -"
    ];

    virtualisation.oci-containers.containers.beszel = {
      image = cfg.image;
      autoStart = true;

      environment = {
        APP_URL = cfg.appUrl;
      };

      volumes = [
        "${cfg.dataDir}/hub:/beszel_data"
      ];

      ports = [
        "127.0.0.1:${toString cfg.appPort}:${toString cfg.appPort}"
      ];

      extraOptions = [
        "--hostname=beszel"
        "--userns=host"
      ];
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.appPort ];
    };

    systemd.services.podman-beszel.after = [ "network-online.target" ];
    systemd.services.podman-beszel.wants = [ "network-online.target" ];
  };
}

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.apps.forgejo;
in
{
  options.apps.forgejo = {
    enable = mkEnableOption "Forgejo container stack";

    image = mkOption {
      type = types.str;
      default = "codeberg.org/forgejo/forgejo:14";
      description = "Container image for Forgejo";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/forgejo";
      description = "Base data directory for Forgejo";
    };

    appPort = mkOption {
      type = types.port;
      default = 3000;
      description = "Internal port used by Forgejo";
    };

    appUrl = mkOption {
      type = types.str;
      default = "https://forgejo.fiordland-gar.ts.net";
      description = "Public URL advertised by Forgejo";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the Forgejo port on the host firewall";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root - -"
    ];

    virtualisation.oci-containers.containers.forgejo = {
      image = cfg.image;
      autoStart = true;

      environment = {
        FORGEJO__server__ROOT_URL = cfg.appUrl;
      };

      volumes = [
        "${cfg.dataDir}:/data"
      ];

      ports = [
        "127.0.0.1:${toString cfg.appPort}:${toString cfg.appPort}"
      ];

      extraOptions = [
        "--hostname=forgejo"
        "--userns=host"
      ];
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.appPort ];
    };

    systemd.services.podman-forgejo.after = [ "network-online.target" ];
    systemd.services.podman-forgejo.wants = [ "network-online.target" ];
  };
}

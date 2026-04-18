{ config, lib, ... }:

let
  cfg = config.apps.jellyseerr;
in
{
  options.apps.jellyseerr = {
    enable = lib.mkEnableOption "Jellyseerr container";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/jellyseerr";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5055;
    };

    uid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
    };

    gid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";
    virtualisation.podman.enable = true;

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${toString cfg.uid} ${toString cfg.gid} -"
    ];

    virtualisation.oci-containers.containers.jellyseerr = {
      image = "ghcr.io/seerr-team/seerr:latest";

      ports = [ "${toString cfg.port}:5055" ];

      volumes = [
        "${cfg.dataDir}:/app/config"
      ];

      environment = {
        TZ = "Europe/Amsterdam";
        PORT = "5055";
      };

      extraOptions = [
        "--network=bridge"
        "--health-cmd=none"
      ];
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}

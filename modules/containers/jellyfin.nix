{ config, lib, ... }:

let
  cfg = config.apps.jellyfin;
in
{
  options.apps.jellyfin = {
    enable = lib.mkEnableOption "Jellyfin container";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/jellyfin";
    };

    mediaDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/shares/Media";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    enableHardwareAcceleration = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";
    virtualisation.podman.enable = true;

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 1000 1000 -"
    ];

    virtualisation.oci-containers.containers.jellyfin = {
      image = "docker.io/jellyfin/jellyfin:latest";

      ports = [ "8096:8096" ];

      volumes = [
        "${cfg.dataDir}:/config"
        "${cfg.mediaDir}:/media:ro"
      ];

      environment = {
        TZ = "Europe/Amsterdam";
      };

      extraOptions =
        [
          "--network=bridge"
          "--group-add=303"
          "--health-cmd=none"
        ]
        ++ lib.optionals cfg.enableHardwareAcceleration [
          "--device=/dev/dri/renderD128:/dev/dri/renderD128"
        ];
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ 8096 ];
    };
  };
}


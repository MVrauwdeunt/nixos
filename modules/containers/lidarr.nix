{ config, lib, ... }:

let
  cfg = config.apps.lidarr;
in
{
  options.apps.lidarr = {
    enable = lib.mkEnableOption "Lidarr container";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/lidarr";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8686;
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.lidarr = {
      image = "lscr.io/linuxserver/lidarr:latest";

      ports = [ "${toString cfg.port}:8686" ];

      volumes = [
        "${cfg.dataDir}:/config"
        "/mnt/shares/Downloads/Muziek:/downloads"
        "/mnt/shares/Media/Muziek:/music"
      ];

      environment = {
        TZ = "Europe/Amsterdam";
        PUID = "1000";
        PGID = "1000";
      };

      extraOptions = [
        "--network=bridge"
        "--health-cmd=none"
      ];
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 1000 1000 -"
    ];

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}

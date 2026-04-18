{ config, lib, ... }:

let
  cfg = config.apps.sonarr;
in
{
  options.apps.sonarr = {
    enable = lib.mkEnableOption "Sonarr container";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/sonarr";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8989;
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.sonarr = {
      image = "lscr.io/linuxserver/sonarr:latest";

      ports = [ "${toString cfg.port}:8989" ];

      volumes = [
        "${cfg.dataDir}:/config"
        "/mnt/shares/Downloads/Series:/downloads"
        "/mnt/shares/Media/Series:/media"
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

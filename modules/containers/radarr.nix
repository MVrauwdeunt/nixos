{ config, lib, ... }:

let
  cfg = config.apps.radarr;
in
{
  options.apps.radarr = {
    enable = lib.mkEnableOption "Radarr container";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/radarr";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 7878;
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.radarr = {
      image = "lscr.io/linuxserver/radarr:latest";

      ports = [ "${toString cfg.port}:7878" ];

      volumes = [
        "${cfg.dataDir}:/config"
        "/mnt/shares/Downloads/Films:/downloads"
        "/mnt/shares/Media/Films:/media"
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

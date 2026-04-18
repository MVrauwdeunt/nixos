{ config, lib, ... }:

let
  cfg = config.apps.sabnzbd;
in
{
  options.apps.sabnzbd = {
    enable = lib.mkEnableOption "SABnzbd container";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/sabnzbd";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8081;
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.sabnzbd = {
      image = "lscr.io/linuxserver/sabnzbd:latest";

      ports = [ "${toString cfg.port}:8080" ];

      volumes = [
        "${cfg.dataDir}:/config"
        "/mnt/shares/Downloads:/downloads"
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

{ config, lib, ... }:

let
  cfg = config.apps.bazarr;
in
{
  options.apps.bazarr = {
    enable = lib.mkEnableOption "Bazarr container";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/bazarr";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 6767;
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.bazarr = {
      image = "lscr.io/linuxserver/bazarr:latest";

      ports = [ "${toString cfg.port}:6767" ];

      volumes = [
        "${cfg.dataDir}:/config"
        "/mnt/shares/Media/Films:/movies"
        "/mnt/shares/Media/Series:/tv"
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

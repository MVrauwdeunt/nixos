{ config, lib, ... }:

let
  cfg = config.apps.newtarr;
in
{
  options.apps.newtarr = {
    enable = lib.mkEnableOption "NewtArr container";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/newtarr";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9705;
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.newtarr = {
      image = "ghcr.io/elfhosted/newtarr:latest";

      ports = [
        "${toString cfg.port}:9705"
      ];

      volumes = [
        "${cfg.dataDir}:/config"
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
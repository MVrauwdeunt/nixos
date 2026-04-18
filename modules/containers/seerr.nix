{ config, lib, ... }:

let
  cfg = config.apps.seerr;
in
{
  options.apps.seerr = {
    enable = lib.mkEnableOption "Seerr container";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/seerr";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5055;
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.seerr = {
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

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 1000 1000 -"
    ];

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}

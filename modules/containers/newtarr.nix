
{ config, lib, ... }:

let
  cfg = config.apps.newtarr;
in
{
  options.apps.newtarr = {
    enable = lib.mkEnableOption "NewtArr container";

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Sonarr through Tailscale Serve.";
    };

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
      image = "ghcr.io/elfhosted/newtarr:v1.0.0@sha256:6abafe8ee23c96e3c9e298b5f9ef8313f1d231546b794900d4da36caa22912f0";
      pull = "missing";

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

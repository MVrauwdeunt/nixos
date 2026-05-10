{ config, lib, ... }:

let
  cfg = config.apps.profilarr;
in
{
  options.apps.profilarr = {
    enable = lib.mkEnableOption "Profilarr container";

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Sonarr through Tailscale Serve.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/profilarr";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 6868;
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.profilarr = {
      image = "docker.io/santiagosayshey/profilarr:latest";

      ports = [
        "127.0.0.1:${toString cfg.port}:6868"
      ];

      volumes = [
        "${cfg.dataDir}:/config"
      ];

      environment = {
        PUID = "1000";
        PGID = "1000";
        UMASK = "022";
        TZ = "Europe/Amsterdam";
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
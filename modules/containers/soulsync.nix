{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.apps.soulsync;
in
{
  options.apps.soulsync = {
    enable = mkEnableOption "SoulSync container";

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Sonarr through Tailscale Serve.";
    };

    image = mkOption {
      type = types.str;
      default = "ghcr.io/nezreka/soulsync:latest";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/soulsync";
    };

    musicDir = mkOption {
      type = types.path;
      default = "/mnt/Volume2/music";
    };

    port = mkOption {
      type = types.port;
      default = 3001;
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers.soulsync = {
      image = cfg.image;

      ports = [ "${toString cfg.port}:3000" ];

      volumes = [
        "${cfg.dataDir}:/config"
        "/mnt/shares/Downloads/Muziek:/downloads"
        "/mnt/shares/Media/Muziek:/music"
      ];

      environment = {
        TZ = "Europe/Amsterdam";
      };

      labels = {
        "app" = "soulsync";
      };
    };
  };
}
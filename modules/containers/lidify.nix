{ config, lib, ... }:

with lib;

let
  cfg = config.apps.lidify;
in
{
  options.apps.lidify = {
    enable = mkEnableOption "Lidify container";

    image = mkOption {
      type = types.str;
      default = "docker.io/thewicklowwolf/lidify:latest";
      description = "Lidify container image.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/lidify";
      description = "Lidify application data directory.";
    };

    configFile = mkOption {
      type = types.path;
      description = "SOPS-provided env file for Lidify.";
    };

    port = mkOption {
      type = types.port;
      default = 5000;
      description = "Lidify web UI port.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the Lidify web UI port in the firewall.";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers.lidify = {
      image = cfg.image;

      ports = [
        "${toString cfg.port}:5000"
      ];

      volumes = [
        "${cfg.dataDir}:/lidify/config"
        "/etc/localtime:/etc/localtime:ro"
      ];

      environmentFiles = [
        cfg.configFile
      ];

      environment = {
        TZ = "Europe/Amsterdam";
        PUID = "1000";
        PGID = "1000";

        mode = "LastFM";
        lidarr_address = "http://192.168.178.240:8686";
        root_folder_path = "/music";

        search_for_missing_albums = "False";
        dry_run_adding_to_lidarr = "False";
      };

      extraOptions = [
        "--network=bridge"
        "--health-cmd=none"
      ];
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 1000 1000 -"
    ];

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
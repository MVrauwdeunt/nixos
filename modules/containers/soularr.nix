{ config, lib, ... }:

with lib;

let
  cfg = config.apps.soularr;
in
{
  options.apps.soularr = {
    enable = mkEnableOption "Soularr container";

    image = mkOption {
      type = types.str;
      default = "docker.io/mrusse08/soularr:latest";
      description = "Soularr container image.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/soularr";
      description = "Soularr application data directory.";
    };

    downloadsDir = mkOption {
      type = types.str;
      default = "/mnt/shares/Downloads/Muziek/soularr";
      description = "Host directory used by Soularr for downloads.";
    };

    configSecretName = mkOption {
      type = types.str;
      default = "mimir/soularr/config_ini";
      description = "SOPS secret name for the Soularr config.ini.";
    };

    port = mkOption {
      type = types.port;
      default = 8265;
      description = "Soularr web UI port.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the Soularr web UI port in the firewall.";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers.soularr = {
      image = cfg.image;

      ports = [
        "${toString cfg.port}:8265"
      ];

      volumes = [
        "${cfg.dataDir}:/data"
        "${config.sops.secrets.${cfg.configSecretName}.path}:/data/config.ini:ro"
        "${cfg.downloadsDir}:/downloads"
      ];

      environment = {
        TZ = "Europe/Amsterdam";
      };

      extraOptions = [
        "--user=1000:1000"
        "--network=bridge"
        "--health-cmd=none"
      ];
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 1000 1000 -"
      "d ${cfg.downloadsDir} 0755 1000 1000 -"
      "d ${cfg.downloadsDir}/complete 0755 1000 1000 -"
      "d ${cfg.downloadsDir}/incomplete 0755 1000 1000 -"
      "d ${cfg.downloadsDir}/failed_imports 0755 1000 1000 -"
    ];

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
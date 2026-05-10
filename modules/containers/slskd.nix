{ config, lib, ... }:

with lib;

let
  cfg = config.apps.slskd;
in
{
  options.apps.slskd = {
    enable = mkEnableOption "slskd container";

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Sonarr through Tailscale Serve.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/slskd";
    };

    downloadsDir = mkOption {
      type = types.str;
      default = "/mnt/shares/Downloads/Muziek/soularr";
    };

    port = mkOption {
      type = types.port;
      default = 5030;
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers.slskd = {
      image = "docker.io/slskd/slskd:latest";

      ports = [ "${toString cfg.port}:5030" ];

      volumes = [
        "${cfg.dataDir}:/app"
        "${cfg.downloadsDir}:/downloads"
      ];

      environment = {
        TZ = "Europe/Amsterdam";
        SLSKD_REMOTE_CONFIGURATION = "true";
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0775 zanbee users -"
      "d ${cfg.downloadsDir} 0775 zanbee users -"
      "d ${cfg.downloadsDir}/incomplete 0775 zanbee users -"
      "d ${cfg.downloadsDir}/complete 0775 zanbee users -"
    ];

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
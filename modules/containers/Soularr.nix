{ config, lib, ... }:

let
  cfg = config.apps.soularr;
in
{
  options.apps.soularr = {
    enable = lib.mkEnableOption "Soularr container";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/soularr";
    };

    downloadsDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/shares/Downloads/Muziek/soularr";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8265;
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.soularr = {
      image = "mrusse08/soularr:latest";

      ports = [ "${toString cfg.port}:8265" ];

      volumes = [
        "${cfg.dataDir}:/data"
        "${cfg.downloadsDir}:/downloads"
      ];

      environment = {
        TZ = "Europe/Amsterdam";
        PUID = "1000";
        PGID = "1000";
        SCRIPT_INTERVAL = "300";
        WEBUI_ENABLED = "true";
        WEBUI_PORT = "8265";
      };

      extraOptions = [
        "--network=bridge"
        "--health-cmd=none"
        "--user=1000:1000"
      ];
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 1000 1000 -"
      "d ${cfg.downloadsDir} 0755 1000 1000 -"
    ];

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
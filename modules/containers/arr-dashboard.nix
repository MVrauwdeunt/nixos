{ config, lib, ... }:
let
  cfg = config.apps.arr-dashboard;
  publicHost = "${cfg.tailscale.serviceName}.fiordland-gar.ts.net";
  publicUrl = "https://${publicHost}";
in
{
  options.apps.arr-dashboard = {
    enable = lib.mkEnableOption "Arr Dashboard container";
    tailscale = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Expose Arr Dashboard through Tailscale Serve.";
      };
      serviceName = lib.mkOption {
        type = lib.types.str;
        default = "arr-dashboard";
        description = "Tailscale service name.";
      };
    };
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/arr-dashboard";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.arr-dashboard = {
      image = "docker.io/khak1s/arr-dashboard:2.24.1@sha256:bd24ff75a61708de22c31947ea8f7efbe1c44ea870c3af9eb0f021968c5d4bab";
      pull = "missing";
      ports = [ "${toString cfg.port}:3000" ];
      volumes = [ "${cfg.dataDir}:/config" ];
      environment = {
        TZ = "Europe/Amsterdam";
        PUID = "1000";
        PGID = "1000";
        APP_URL = publicUrl;
        API_CORS_ORIGIN = publicUrl;
        WEBAUTHN_RP_NAME = "Arr Dashboard";
        WEBAUTHN_RP_ID = publicHost;
        WEBAUTHN_ORIGIN = publicUrl;
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
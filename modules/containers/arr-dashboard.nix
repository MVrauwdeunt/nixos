# modules/containers/arr-dashboard.nix
{ config, lib, ... }:

let
  cfg = config.apps.arr-dashboard;
in
{
  options.apps.arr-dashboard = {
    enable = lib.mkEnableOption "Arr Dashboard container";

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Arr Dashboard through Tailscale Serve.";
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
      image = "docker.io/khak1s/arr-dashboard:latest";
      pull = "always";

      ports = [
        "${toString cfg.port}:3000"
      ];

      volumes = [
        "${cfg.dataDir}:/config"
      ];

      environment = {
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
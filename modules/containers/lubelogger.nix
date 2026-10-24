
{ config, lib, ... }:

let
  cfg = config.apps.lubelogger;
in
{
  options.apps.lubelogger = {
    enable = lib.mkEnableOption "LubeLogger container";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/hargata/lubelogger@sha256:c9d2bbb48c7f84d90e54496e2cd60422e56a5f2345c8a539ebe09f77e629d321";
      description = "LubeLogger container image";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/lubelogger";
      description = "Persistent LubeLogger data directory";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8082;
      description = "LubeLogger web UI port";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose LubeLogger through Tailscale Serve";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";

    virtualisation.oci-containers.containers.lubelogger = {
      image = cfg.image;
      pull = "missing";
      autoStart = true;

      ports = [
        "127.0.0.1:${toString cfg.port}:8080"
      ];

      volumes = [
        "${cfg.dataDir}/data:/App/data"
        "${cfg.dataDir}/keys:/root/.aspnet/DataProtection-Keys"
      ];

      environment = {
        TZ = "Europe/Amsterdam";
      };

      extraOptions = [
        "--network=bridge"
        "--security-opt=no-new-privileges"
      ];
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
      "d ${cfg.dataDir}/data 0755 root root -"
      "d ${cfg.dataDir}/keys 0700 root root -"
    ];

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };

    systemd.services.podman-lubelogger = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
    };
  };
}

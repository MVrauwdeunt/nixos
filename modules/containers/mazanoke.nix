{ config, lib, ... }:

let
  cfg = config.apps.mazanoke;
in
{
  options.apps.mazanoke = {
    enable = lib.mkEnableOption "Mazanoke container";

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Mazanoke through Tailscale Serve.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3474;
      description = "Mazanoke web UI port.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.mazanoke = {
      image = "ghcr.io/civilblur/mazanoke:latest";
      pull = "always";
      
      ports = [
        "${toString cfg.port}:80"
      ];

      extraOptions = [
        "--network=bridge"
        "--health-cmd=none"
      ];
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
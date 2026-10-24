{ config, lib, ... }:
let cfg = config.apps.mazanoke;
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
      image = "ghcr.io/civilblur/mazanoke:v1.1.7@sha256:ca83cddd90cd1e4b43102884bf39025731a1c7569f3bbda9d6530de72528cbab";
      pull = "missing";
      ports = [ "${toString cfg.port}:80" ];
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
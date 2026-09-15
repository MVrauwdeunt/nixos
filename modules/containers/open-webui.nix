# modules/containers/open-webui.nix
{ config, lib, ... }:

let
  cfg = config.apps.open-webui;
in
{
  options.apps.open-webui = {
    enable = lib.mkEnableOption "Open WebUI";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Local Open WebUI web port.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the Open WebUI port in the firewall.";
    };

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Open WebUI through Tailscale Services.";
    };

    tailscale.serviceName = lib.mkOption {
      type = lib.types.str;
      default = "openwebui";
      description = "Tailscale Service name.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /var/lib/open-webui 0755 root root -"
    ];

    virtualisation.oci-containers.containers.open-webui = {
      image = "ghcr.io/open-webui/open-webui@sha256:1a6399d237dc392a2313e0ca826020b3fd5d22536357840eb63393d18dc8b924";

      ports = [
        "127.0.0.1:${toString cfg.port}:8080"
      ];

      volumes = [
        "/var/lib/open-webui:/app/backend/data"
      ];
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
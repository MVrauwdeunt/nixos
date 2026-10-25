
{ config, lib, ... }:

let
  cfg = config.apps.spoolman;
in
{
  options.apps.spoolman = {
    enable = lib.mkEnableOption "Spoolman";

    port = lib.mkOption {
      type = lib.types.port;
      default = 7912;
      description = "Local Spoolman web port.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Spoolman through Tailscale Services.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /var/lib/spoolman 0755 - - -"
    ];

    virtualisation.oci-containers.containers.spoolman = {
      image = "ghcr.io/donkie/spoolman:0.27.0@sha256:7aba565eff774c6dda212d4204de8fa30bf68d513127ef875cc7ef3197a4664e";
      pull = "missing";

      ports = [
        "127.0.0.1:${toString cfg.port}:8000"
      ];

      volumes = [
        "/var/lib/spoolman:/home/app/.local/share/spoolman"
      ];

      environment = {
        TZ = "Europe/Amsterdam";
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}

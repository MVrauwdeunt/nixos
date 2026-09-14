{ config, lib, ... }:

let
  cfg = config.apps.mealie;
in
{
  options.apps.mealie = {
    enable = lib.mkEnableOption "Mealie";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9000;
      description = "Local Mealie web port.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Mealie through Tailscale Services.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."saga/mealie_openai_api_key" = {};

    sops.templates."mealie.env".content = ''
      OPENAI_API_KEY=${config.sops.placeholder."saga/mealie_openai_api_key"}
    '';

    systemd.tmpfiles.rules = [
      "d /var/lib/mealie 0755 1000 1000 -"
    ];

    virtualisation.oci-containers.containers.mealie = {
      image = "ghcr.io/mealie-recipes/mealie:v2.8.0";

      ports = [
        "127.0.0.1:${toString cfg.port}:9000"
      ];

      environment = {
        ALLOW_SIGNUP = "false";
        PUID = "1000";
        PGID = "1000";

        # Keep the existing timezone during migration.
        TZ = "Europe/Amsterdam";

        BASE_URL = "https://mealie.fiordland-gar.ts.net";
      };

      environmentFiles = [
        config.sops.templates."mealie.env".path
      ];

      volumes = [
        "/var/lib/mealie:/app/data"
      ];
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
{ config, lib, ... }:

let
  cfg = config.services.beszel-hub;
in
{
  options.services.beszel-hub = {
    enable = lib.mkEnableOption "Beszel hub";

    hostName = lib.mkOption {
      type = lib.types.str;
      default = "beszel.example.com";
      description = "Public hostname for the Beszel hub.";
    };

    acmeEmail = lib.mkOption {
      type = lib.types.str;
      default = "admin@example.com";
      description = "Email address used for ACME registration.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to expose the Beszel hub port directly.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8090;
      description = "Local port used by the Beszel hub.";
    };

    enableNginx = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to expose Beszel through nginx.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.beszel.hub = {
      enable = true;

      # Local port for the Beszel web interface
      port = cfg.port;
    };

    networking.firewall.allowedTCPPorts =
      lib.mkIf cfg.openFirewall [ cfg.port ];

    services.nginx = lib.mkIf cfg.enableNginx {
      enable = true;

      virtualHosts.${cfg.hostName} = {
        # Enable automatic HTTPS for the public hostname
        enableACME = true;
        forceSSL = true;

        locations."/" = {
          # Proxy traffic to the local Beszel hub
          proxyPass = "http://127.0.0.1:${toString cfg.port}";

          # Required for websocket support
          proxyWebsockets = true;
        };
      };
    };

    security.acme = lib.mkIf cfg.enableNginx {
      acceptTerms = true;
      defaults.email = cfg.acmeEmail;
    };
  };
}

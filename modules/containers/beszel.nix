{ config, pkgs, lib, ... }:

{
  services.beszel = {
    hub = {
      enable = true;

      # Port where the Beszel web UI will be available
      port = 8090;
    };

    agent = {
      enable = true;

      # Load sensitive values (KEY, TOKEN, HUB_URL) from a file
      # This prevents secrets from ending up in the Nix store
      environmentFile = config.age.secrets.beszel-agent.path;

      # Optional: expose additional system tools for richer metrics
      extraPath = with pkgs; [
        smartmontools
        lm_sensors
      ];

      # Do not open firewall by default
      # The agent only needs outbound access to the hub
      openFirewall = false;
    };
  };

  # Optional: reverse proxy configuration using nginx
  services.nginx = {
    enable = true;

    virtualHosts."beszel.gladsheimr.nl" = {
      forceSSL = true;
      enableACME = true;

      locations."/" = {
        # Forward traffic to the local Beszel hub
        proxyPass = "http://127.0.0.1:${toString config.services.beszel.hub.port}";

        # Required for websocket support
        proxyWebsockets = true;
      };
    };
  };
}

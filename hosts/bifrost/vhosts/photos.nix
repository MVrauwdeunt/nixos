# hosts/bifrost/vhosts/photos.nix
{ config, lib, ... }:
{
  modules.caddyCompose = {
    enable = true;

    # E-mail voor Let's Encrypt (CADDY_EMAIL)
    email = "admin@gladsheimr.nl";

    # Zet vhost(s)
    virtualHosts."photos.gladsheimr.nl" = {
      # We willen HTTPS upstream met correcte SNI/Host naar tailscale-host:
      upstream = ''
        https://photos.fiordland-gar.ts.net {
          # Zorg dat SNI + Host op upstream kloppen (niet de public host)
          header_up Host {upstream_hostport}
        }
      '';

      # Extra harde headers
      extraConfig = ''
        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        }
      '';
    };
  };
}


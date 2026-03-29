{ lib, ... }:
{
  apps.caddy.virtualHosts."view.gladsheimr.nl" = {
    upstream = "http://100.103.30.4:8888";

    extraConfig = ''
      encode gzip

      # Stuur root direct naar de drone-feed
      redir / /drone

      header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        Referrer-Policy "strict-origin-when-cross-origin"
      }
    '';
  };
}

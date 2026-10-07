{ ... }:
{
  apps.caddy.virtualHosts."auth.gladsheimr.nl" = {
    upstream = "http://127.0.0.1:9091";

    extraConfig = ''
      encode gzip

      header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        Referrer-Policy "strict-origin-when-cross-origin"
      }
    '';
  };
}
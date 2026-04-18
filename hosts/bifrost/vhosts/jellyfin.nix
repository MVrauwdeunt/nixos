{ ... }:
{
  apps.caddy.virtualHosts."jellyfin.gladsheimr.nl" = {
    upstream = "https://jellyfin.fiordland-gar.ts.net";

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

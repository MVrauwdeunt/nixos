
{ ... }:

{
  apps.caddy.virtualHosts."ai.gladsheimr.nl" = {
    upstream = "https://openwebui.fiordland-gar.ts.net";

    proxyExtraConfig = ''
      header_up Host {host}
      header_up X-Forwarded-Host {host}
      header_up X-Forwarded-Proto {scheme}
    '';

    extraConfig = ''
      encode gzip

      header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        Referrer-Policy "strict-origin-when-cross-origin"
      }
    '';
  };
}

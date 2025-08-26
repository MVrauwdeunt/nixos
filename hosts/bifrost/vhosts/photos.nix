# hosts/bifrost/vhosts/photos.nix
{ lib, ... }:
{
  apps.caddy.virtualHosts."photos.gladsheimr.nl" = {
    # HTTPS upstream via Tailscale with correct SNI/Host to the tailnet service
    upstream = ''
      https://photos.fiordland-gar.ts.net {
        header_up Host {upstream_hostport}
      }
    '';

    # Extra security headers / policies
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

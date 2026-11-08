
{ ... }:

let
  securityHeaders = import ../caddy-security-headers.nix;
in
{
  apps.caddy.virtualHosts."dawarich.gladsheimr.nl" = {
    upstream = "https://dawarich.fiordland-gar.ts.net";

    extraConfig = ''
      encode gzip

      ${securityHeaders {}}
    '';
  };
}

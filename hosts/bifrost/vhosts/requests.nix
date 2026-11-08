
{ ... }:

let
  securityHeaders = import ../caddy-security-headers.nix;
in
{
  apps.caddy.virtualHosts."requests.gladsheimr.nl" = {
    upstream = "https://seerr.fiordland-gar.ts.net";

    extraConfig = ''
      encode gzip

      ${securityHeaders {}}
    '';
  };
}

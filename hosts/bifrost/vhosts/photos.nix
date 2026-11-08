
{ ... }:

let
  securityHeaders = import ../caddy-security-headers.nix;
in
{
  apps.caddy.virtualHosts."photos.gladsheimr.nl" = {
    upstream = "https://photos.fiordland-gar.ts.net";

    extraConfig = ''
      encode gzip

      ${securityHeaders {}}
    '';
  };
}

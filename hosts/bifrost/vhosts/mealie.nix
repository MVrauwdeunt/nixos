
{ ... }:

let
  securityHeaders = import ../caddy-security-headers.nix;
in
{
  apps.caddy.virtualHosts."mealie.gladsheimr.nl" = {
    upstream = "https://mealie.fiordland-gar.ts.net";

    extraConfig = ''
      encode gzip

      ${securityHeaders {}}
    '';
  };
}

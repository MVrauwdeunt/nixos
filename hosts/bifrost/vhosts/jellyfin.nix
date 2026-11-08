
{ ... }:

let
  securityHeaders = import ../caddy-security-headers.nix;
in
{
  apps.caddy.virtualHosts."jellyfin.gladsheimr.nl" = {
    upstream = "https://jellyfin.fiordland-gar.ts.net";

    extraConfig = ''
      encode gzip

      ${securityHeaders {}}
    '';
  };
}

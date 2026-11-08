
{ ... }:

let
  securityHeaders = import ../caddy-security-headers.nix;
in
{
  apps.caddy.virtualHosts."view.gladsheimr.nl" = {
    upstream = "http://100.103.30.4:8888";

    extraConfig = ''
      encode gzip

      # Stuur root direct naar de drone-feed
      redir / /drone

      ${securityHeaders {}}
    '';
  };
}

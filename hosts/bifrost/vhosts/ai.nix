
{ ... }:

let
  securityHeaders = import ../caddy-security-headers.nix;
in
{
  apps.caddy.virtualHosts."ai.gladsheimr.nl" = {
    upstream = "https://openwebui.fiordland-gar.ts.net";

    proxyExtraConfig = ''
      header_up Host {host}
    '';

    extraConfig = ''
      encode gzip

      ${securityHeaders { preload = false; }}
    '';
  };
}

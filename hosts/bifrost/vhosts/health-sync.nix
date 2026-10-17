{ ... }:
{
  apps.caddy.virtualHosts."health-sync.gladsheimr.nl" = {
    upstream = "https://health.fiordland-gar.ts.net";

    extraConfig = ''
      @wrongPath not path /api/integrations/health-connect/ingest
      respond @wrongPath 404

      @wrongMethod not method POST
      respond @wrongMethod 404

      header {
        Cache-Control "no-store"
        X-Content-Type-Options "nosniff"
      }
    '';
  };
}
{ ... }: 

{
  modules.caddyCompose.virtualHosts."photos.gladsheimr.nl" = {
    upstream = "http://photos.fiordland-gar.ts.net"; # pas poort aan
    extraConfig = ''
      header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
      }
      # Voor bepaalde foto-apps (Immich/PhotoPrism) kun je later upload/WS tweaks toevoegen.
    '';
  };
}


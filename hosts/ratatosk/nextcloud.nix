{ config, pkgs, ... }:

let
  hostName = "cloud.openmailbox.nl";
in
{
  services.nextcloud = {
    enable = true;
    inherit hostName;

    # Expliciet pinnen is aanbevolen door NixOS.
    # Voor een nieuwe installatie kunnen we direct op de actuele major starten.
    package = pkgs.nextcloud34;

    https = true;

    database.createLocally = true;
    configureRedis = true;

    config = {
      dbtype = "pgsql";

      adminuser = "zanbee";

      adminpassFile =
        config.sops.secrets."ratatosk/nextcloud/admin-password".path;
    };

    settings = {
      default_phone_region = "NL";
      overwriteprotocol = "https";
    };
  };

  services.nginx.virtualHosts.${hostName} = {
    enableACME = true;
    forceSSL = true;
  };
}
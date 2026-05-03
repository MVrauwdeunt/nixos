{ config, ... }:

{
  apps.soularr = {
    enable = true;
    dataDir = "/var/lib/soularr";
    downloadsDir = "/mnt/shares/Downloads/Muziek/soularr";

    configFile =
      config.sops.secrets."mimir/soularr/config_ini".path;

    openFirewall = false;
  };
}
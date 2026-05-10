{ config, ... }:

{
  apps.lidify = {
    enable = true;
    dataDir = "/var/lib/lidify";
    configFile = config.sops.secrets."mimir/lidify/env".path;
    openFirewall = false;
  };
}
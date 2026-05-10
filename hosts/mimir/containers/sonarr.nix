{ ... }:
{
  apps.sonarr = {
    enable = true;
    dataDir = "/var/lib/sonarr";
    openFirewall = false;
  };
}

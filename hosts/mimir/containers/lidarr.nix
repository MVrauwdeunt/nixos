{ ... }:
{
  apps.lidarr = {
    enable = true;
    dataDir = "/var/lib/lidarr";
    openFirewall = false;
  };
}

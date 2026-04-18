{ ... }:
{
  apps.jellyseerr = {
    enable = true;
    dataDir = "/var/lib/jellyseerr";
    openFirewall = false;
    port = 5055;
  };
}


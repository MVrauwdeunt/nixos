{ ... }:
{
  apps.jellyfin = {
    enable = true;

    dataDir = "/var/lib/jellyfin";
    mediaDir = "/mnt/shares/Media";

    openFirewall = false;
    enableHardwareAcceleration = true;
  };
}

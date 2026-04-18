{ ... }:
{
  apps.sabnzbd = {
    enable = true;
    dataDir = "/var/lib/sabnzbd";
    openFirewall = false;
  };
}

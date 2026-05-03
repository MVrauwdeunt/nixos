{ ... }:

{
  apps.soularr = {
    enable = true;
    dataDir = "/var/lib/soularr";
    downloadsDir = "/mnt/shares/Downloads/Muziek/soularr";
    openFirewall = false;
  };
}
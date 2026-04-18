{ ... }:
{
  apps.seerr = {
    enable = true;
    dataDir = "/var/lib/seerr";
    openFirewall = false;
  };
}

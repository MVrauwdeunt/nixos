{ ... }:
{
  apps.bazarr = {
    enable = true;
    dataDir = "/var/lib/bazarr";
    openFirewall = false;
  };
}

{ ... }:
{
  apps.beszel = {
    enable = true;
    dataDir = "/var/lib/beszel";
    appPort = 8090;
    appUrl = "https://beszel.fiordland-gar.ts.net";
    openFirewall = false;
  };
}

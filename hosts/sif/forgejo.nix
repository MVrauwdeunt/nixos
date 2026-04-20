{ ... }:
{
  apps.forgejo = {
    enable = true;

    dataDir = "/var/lib/forgejo";
    image = "codeberg.org/forgejo/forgejo:14";

    appUrl = "https://forgejo.fiordland-gar.ts.net";
    sshDomain = "forgejo.fiordland-gar.ts.net";
    sshPort = 2222;

    openFirewall = false;
  };
}

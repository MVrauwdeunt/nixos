{ config, ... }:
{
  apps.forgejo = {
    enable = true;

    dataDir = "/var/lib/forgejo";
    tailscaleStateDir = "/var/lib/tailscale-forgejo";

    image = "codeberg.org/forgejo/forgejo:14";
    tailscaleImage = "docker.io/tailscale/tailscale:stable";

    tailscaleHostname = "forgejo";
    tailscaleAuthFile = config.sops.secrets."sif/tailscale".path;
    tailscaleAdvertiseTags = [ "tag:container" ];

    appUrl = "https://forgejo.fiordland-gar.ts.net";

    userspaceNetworking = false;
    openFirewall = false;

    serveConfigFile = ../../modules/containers/forgejo-serve.json;
  };
}

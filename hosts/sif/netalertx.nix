{ config, ... }:
{
  apps.netalertx = {
    enable = true;

    dataDir = "/var/lib/netalertx";
    tailscaleStateDir = "/var/lib/tailscale-netalertx";

    uid = 20211;
    gid = 20211;

    timezone = "Europe/Amsterdam";

    port = 20211;
    graphqlPort = 20212;

    tailscaleHostname = "netalertx";
    tailscaleAuthFile = config.sops.secrets."sif/tailscale".path;
    tailscaleAdvertiseTags = [ "tag:container" ];

    userspaceNetworking = false;
    openFirewall = false;

    serveConfigFile = ../../modules/containers/netalertx-serve.json;
  };
}

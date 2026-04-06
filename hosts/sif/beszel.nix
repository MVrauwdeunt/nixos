{ config, ... }:
{
  apps.beszel-agent.enable = true;

  # --------------------------------------------------
  # Beszel
  # --------------------------------------------------
  apps.beszel = {
    enable = true;

    dataDir = "/var/lib/beszel";
    tailscaleStateDir = "/var/lib/tailscale-beszel";

    image = "docker.io/henrygd/beszel:latest";
    tailscaleImage = "docker.io/tailscale/tailscale:stable";

    tailscaleHostname = "beszel";
    tailscaleAuthFile = config.sops.secrets."sif/tailscale".path;
    tailscaleAdvertiseTags = [ "tag:container" ];

    appUrl = "https://beszel.fiordland-gar.ts.net";

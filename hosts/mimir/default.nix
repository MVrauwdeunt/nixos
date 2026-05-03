{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../../modules/users/zanbee
    ../../modules/containers/jellyfin.nix
    ../../modules/containers/seerr.nix
    ../../modules/containers/prowlarr.nix
    ../../modules/containers/radarr.nix
    ../../modules/containers/sonarr.nix
    ../../modules/containers/bazarr.nix
    ../../modules/containers/lidarr.nix
    ../../modules/containers/sabnzbd.nix
    ../../modules/containers/soularr.nix
    ../../modules/containers/slskd.nix

    ./system.nix
    ./networking.nix
    ./sops.nix
    ./tailscale-services.nix
    ./jellyfin.nix
    ./seerr.nix
    ./prowlarr.nix
    ./radarr.nix
    ./sonarr.nix
    ./bazarr.nix
    ./lidarr.nix
    ./sabnzbd.nix
    ./soularr.nix
    ./slskd.nix 
  ];
  # apps.beszel-agent.enable = true;
}

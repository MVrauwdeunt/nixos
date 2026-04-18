{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../../modules/users/zanbee
    ../../modules/containers/jellyfin.nix
    ../../modules/containers/seerr.nix

    ./system.nix
    ./networking.nix
    ./sops.nix
    ./tailscale-services.nix
    ./jellyfin.nix
    ./seerr.nix
  ];
  # apps.beszel-agent.enable = true;
}


{ modulesPath, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")

    ../../modules/users/zanbee
    ../../modules/podman-networks.nix
    ../../modules/tailscale-services.nix

    ./system.nix
    ./networking.nix
    ./sops.nix
    ./apps.nix
  ];

  infrastructure.podman.networks.arr-internal = true;

  # apps.beszel-agent.enable = true;
}

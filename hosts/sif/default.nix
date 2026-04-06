{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../../modules/users/zanbee
    ../../modules/containers/unifi.nix
    ../../modules/containers/beszel.nix
    ../../modules/containers/netalertx.nix

    ./system.nix
    ./networking.nix
    ./sops.nix
    ./unifi.nix
    ./beszel.nix
    ./netalertx.nix
  ];
}

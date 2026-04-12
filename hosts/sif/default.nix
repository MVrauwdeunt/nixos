{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../../modules/users/zanbee
    ../../modules/containers/unifi.nix
    ../../modules/containers/beszel.nix
    ../../modules/containers/netalertx.nix
    ../../modules/containers/forgejo.nix

    ./system.nix
    ./networking.nix
    ./sops.nix
    ./tailscale-services.nix
    ./unifi.nix
    ./beszel.nix
    ./netalertx.nix
    ./forgejo.nix
  ];
  apps.beszel-agent.enable = true;
}

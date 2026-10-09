{ modulesPath, inputs, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../../modules/users/zanbee

    ./system.nix
    ./networking.nix
    ./sops.nix
    ../../modules/tailscale-services.nix
    ../../modules/podman-networks.nix
    # ../../modules/hermes-agent.nix

    ./apps.nix
  ];
  infrastructure.podman.aiBackend.enable = true;
}
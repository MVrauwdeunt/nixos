{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../../modules/users/zanbee

    ./system.nix
    ./networking.nix
    ./sops.nix
  ];
  # apps.beszel-agent.enable = true;
}


{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../../modules/users/zanbee

    ./system.nix
    ./networking.nix
    ./sops.nix
    #./forgejo-runner.nix
    ../../modules/tailscale-services.nix
    ./apps.nix
  ];

  # apps.beszel-agent.enable = true;
}

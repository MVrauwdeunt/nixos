{ modulesPath, lib, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
  ];

  nix.settings.sandbox = false;

  proxmoxLXC = {
    privileged = true;
    manageNetwork = false;
    manageHostName = false;
  };

  services.fstrim.enable = false;
  services.qemuGuest.enable = lib.mkForce false;

  networking.useDHCP = lib.mkForce false;
  networking.useNetworkd = lib.mkForce true;

  systemd.network.enable = lib.mkForce false;

  services.tailscale.enable = lib.mkForce false;
}

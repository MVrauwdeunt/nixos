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

  networking.useDHCP = lib.mkForce false;
  networking.useNetworkd = lib.mkForce true;

  systemd.network.enable = true;
  systemd.network.networks."10-eth0" = {
    matchConfig.Name = "eth0";
    networkConfig = {
      DHCP = "yes";
      IPv6AcceptRA = true;
    };
  };

  services.fstrim.enable = lib.mkForce false;
  services.qemuGuest.enable = lib.mkForce false;

  services.tailscale.enable = lib.mkForce false;
}

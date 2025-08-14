{ lib, ... }:
{
  imports = [ ./hardware-configuration.nix ];
  # networking.hostName = "Bifrost";

  networking.useNetworkd = lib.mkForce false;
  systemd.network.enable = lib.mkForce false;
  networking.useDHCP = lib.mkForce true;

  # Pas aan als je NVMe hebt:
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };
}

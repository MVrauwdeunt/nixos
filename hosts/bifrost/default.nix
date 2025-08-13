{ ... }:
{
  imports = [ ./hardware-configuration.nix ];
  # networking.hostName = "Bifrost";

  # Pas aan als je NVMe hebt:
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };
}

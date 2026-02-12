{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ../../modules/base.nix
    ../../modules/desktops/xfce.nix
    ../../modules/users/zanbee.nix
  ];
  
  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };

  networking.hostName = "vm";
  # my.users = ["zanbee"];

  # Temp ssh
  services.openssh.enable = true;

}    

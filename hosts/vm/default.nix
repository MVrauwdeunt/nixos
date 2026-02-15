{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ../../modules/base.nix
    ../../modules/users/zanbee
    ../../modules/roles/workstation
  ];
  
  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };

  networking.hostName = "vm";
  # my.users = ["zanbee"];

  # Temp ssh
  services.openssh.enable = true;

  services.tailscale.enable = false;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users.zanbee = import ../../modules/users/zanbee/home-manager.nix;


}    

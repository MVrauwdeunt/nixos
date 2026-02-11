{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ../../modules/base.nix
  ];

  networking.hostName = "vm";

  # Temp ssh
  services.openssh.enable = true;

}    

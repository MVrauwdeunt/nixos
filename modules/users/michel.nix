{ config, pkgs, ... }:

{
  users.users.michel = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
    initialPassword = "changeme";
  };
}

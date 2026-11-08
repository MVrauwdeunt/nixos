
{ lib, ... }:
{

  # SSH policy inherited from modules/ssh-hardened.nix.
  services.openssh.enable = true;
  services.openssh.openFirewall = true;

  system.stateVersion = lib.mkForce "25.11";
}

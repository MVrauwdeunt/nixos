{ pkgs, ... }:
{ inputs, ... }:
{
  users.users.zanbee = {
    isNormalUser = true;
    description = "Zanbee";
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKRs/wq/6uI7umQNWzFC11sxBfeK8ny4ZAq02a+DX2Cv"
    ];
  };
}

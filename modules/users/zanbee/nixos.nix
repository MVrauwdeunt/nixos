{ pkgs, inputs, lib, config, ... }:

let
  cfg = config.my.users.zanbee;
in
{
  options.my.users.zanbee.shell = lib.mkOption {
    type = lib.types.package;
    default = pkgs.bashInteractive; # servers = safe default
    description = "Login shell for user zanbee";
  };

  config.users.users.zanbee = {
    isNormalUser = true;
    description = "Zanbee";
    shell = cfg.shell;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKRs/wq/6uI7umQNWzFC11sxBfeK8ny4ZAq02a+DX2Cv"
    ];
  };
}


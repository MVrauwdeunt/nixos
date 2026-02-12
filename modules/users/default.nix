{ config, lib, ... }:

let
  usersList = config.my.users;
in
{
  options.my.users = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
  };

  imports = map (u: ./. + "/${u}.nix") usersList;
}

{ config, lib, ... }:

let
  userLists = config.my.users;
in
{
  options.my.users. = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
  };

  imports = map (u: ./. + "/${u}.nix") userList;
}

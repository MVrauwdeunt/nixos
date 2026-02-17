{ inputs, lib, config, ... }:

let
  # All normale user on this host
  normalUsers =
    lib.attrNames (lib.filterAttrs (_: u: (u.isNormalUser or false)) config.users.users);

  # Excluded users (ex. “guest”, “temp”, etc.)
  hmExclude = config.hm.excludeUsers;

  targetUsers = lib.filter (u: !(lib.elem u hmExclude)) normalUsers;

  # Path to user HM config
  userHomeFile = u: ../home/users/${u}/home.nix;

  # If file exists: import. Else: minimal HM config to prevent failing.
  mkHmUser = u:
    if builtins.pathExists (userHomeFile u) then
      import (userHomeFile u)
    else
      {
        home.username = u;
        home.homeDirectory = "/home/${u}";
        # Zet dit op jouw NixOS release / HM stateVersion
        home.stateVersion = config.system.stateVersion;
      };

in
{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  options.hm.excludeUs


{ config, lib, pkgs, ... }:

let
  cfg = config.my.users.deploy;
in
{
  options.my.users.deploy.authorizedKeys = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "SSH public keys for NixOS deployments";
  };

  config = {
    users.groups.deploy = { };

    users.users.deploy = {
      isSystemUser = true;
      description = "NixOS deployment service account";

      group = "deploy";
      home = "/var/empty";
      createHome = false;

      shell = pkgs.bash;
      hashedPassword = "!";

      openssh.authorizedKeys.keys = cfg.authorizedKeys;
    };
  };
}
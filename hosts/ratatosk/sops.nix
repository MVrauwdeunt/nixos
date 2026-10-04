# hosts/ratatosk/sops.nix

{ lib, ... }:

{
  ops.age.sshKeyPaths = lib.mkForce [ ];
  sops.secrets."ratatosk/mail/m-vrauwdeunt-password" = { };
  sops.secrets."ratatosk/mail/paperless-password" = { };
  sops.secrets."ratatosk/mail/authelia-password" = { };
}
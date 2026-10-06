# hosts/ratatosk/default.nix

{ inputs, ... }:

{
  imports = [
    ../../modules/users/zanbee
    inputs.nixos-mailserver.nixosModules.default

    ./network.nix
    ./mail.nix
    ./nginx.nix
    ./sops.nix
    ./services.nix
    # ./nextcloud.nix
  ];

  nix.settings.trusted-users = [
    "root"
    "zanbee"
  ];
}
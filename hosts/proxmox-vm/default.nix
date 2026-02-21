{ ... }:

{
  imports = [
    ../../modules/users/zanbee
    ../../modules/roles/workstation
  ];

  services.openssh.enable = true;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.zanbee =
    import ../../modules/users/zanbee/home-manager.nix;
}


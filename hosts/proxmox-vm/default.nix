{ ... }:

{
  # This host uses Disko (configured in flake via useDisko = true)

  imports = [
    ../../modules/users/zanbee
    ../../modules/roles/workstation
  ];

  # Ensure SSH access after nixos-anywhere deployment
  services.openssh.enable = true;

  # Home Manager integration
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users.zanbee =
    import ../../modules/users/zanbee/home-manager.nix;

  # Optional: enable qemu guest tools explicitly (safe for Proxmox)
  services.qemuGuest.enable = true;

  # Optional: explicit DHCP (remove if handled elsewhere)
  networking.useDHCP = true;
}

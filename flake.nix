{
  description = "Declarative NixOS configuration managed via flakes";

  inputs = {
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
    sops-nix.url = "github:Mic92/sops-nix";

    # Home Manager
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, sops-nix, home-manager, ... }:
  let
    lib = nixpkgs.lib;

    hosts = [
      # Bifrost stays legacy (non-disko)
      { name = "bifrost"; platform = "hetzner"; firmware = "bios"; disk = "/dev/sda"; useDisko = false; }

      # Local VM stays legacy for now
      { name = "vm"; platform = "qemu"; firmware = "uefi"; disk = "/dev/vda"; useDisko = false; }

      # Example: Proxmox VM managed by disko + nixos-anywhere
      # { name = "proxmox-vm"; platform = "proxmox"; firmware = "uefi"; disk = "/dev/vda"; useDisko = true; }
      { name = "proxmox-vm"; platform = "proxmox"; firmware = "uefi"; disk = "/dev/vda"; useDisko = true; }
    ];

    mkHost =
      { name
      , platform
      , firmware
      , disk
      , useDisko ? false
      }:
      lib.nameValuePair name (lib.nixosSystem {
        system = "x86_64-linux";

        modules =
          [
            # Home Manager
            home-manager.nixosModules.home-manager

            # Common baseline modules
            ./modules/base.nix
            ./modules/packages.nix
            ./modules/ssh-hardened.nix
            ./modules/just
            sops-nix.nixosModules.sops
            ./modules/sops.nix
            ./modules/tailscale.nix

            # Network module selection
            (if platform == "hetzner" then ./modules/network/hetzner-cloud.nix
             else if platform == "proxmox" then ./modules/network/proxmox-bridge.nix
             else { })

            # Hostname always set here (can still be overridden if needed)
            { networking.hostName = name; }

            # Always import host-specific config (users/roles/services/home-manager/etc.)
            (builtins.toPath ((builtins.toString ./hosts) + "/${name}/default.nix"))

            # ./modules/network/safe-recovery.nix
          ]
          ++ lib.optionals useDisko [
            # Enable disko only when requested
            disko.nixosModules.disko

            # Pick a disko layout module based on firmware
            (if firmware == "uefi"
             then ./modules/disko-uefi-ext4.nix
             else ./modules/disko-bios-ext4.nix)

            # Set the target disk device per host
            { disko.devices.disk.main.device = disk; }

            # BIOS needs grub target disk; UEFI is handled by your UEFI module
            (lib.mkIf (firmware == "bios") {
              boot.loader.grub.device = disk;
            })
          ];
      });
  in
  {
    nixosConfigurations =
      (lib.listToAttrs (map mkHost hosts))
      // {
        installer = lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit sops-nix nixpkgs; };
          modules = [
            ./hosts/installer/default.nix
          ];
        };
      };
  };
}

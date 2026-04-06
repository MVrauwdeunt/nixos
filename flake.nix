{
  description = "Declarative NixOS configuration managed via flakes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    disko.url = "github:nix-community/disko";
    sops-nix.url = "github:Mic92/sops-nix";
    deploy-rs.url = "github:serokell/deploy-rs";

    # Home Manager
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, sops-nix, home-manager, deploy-rs, ... }:
  let
    lib = nixpkgs.lib;
    system = "x86_64-linux";

    hosts = [
      { name = "bifrost"; platform = "hetzner"; firmware = "bios"; disk = "/dev/sda"; useDisko = false; }
      { name = "sif"; platform = "proxmox"; firmware = "bios"; disk = "/dev/sda"; useDisko = false; }
      { name = "vm"; platform = "qemu"; firmware = "uefi"; disk = "/dev/vda"; useDisko = false; }
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
        inherit system;

        modules =
          [
            home-manager.nixosModules.home-manager

            ./modules/base.nix
            ./modules/packages.nix
            ./modules/ssh-hardened.nix
            ./modules/just
            sops-nix.nixosModules.sops
            ./modules/sops.nix
            ./modules/tailscale.nix
            ./modules/services/beszel-agent.nix

            (if platform == "hetzner" then ./modules/network/hetzner-cloud.nix
             else if platform == "proxmox" then ./modules/network/proxmox-bridge.nix
             else { })

            { networking.hostName = name; }

            (builtins.toPath ((builtins.toString ./hosts) + "/${name}/default.nix"))
          ]
          ++ lib.optionals useDisko [
            disko.nixosModules.disko

            (if firmware == "uefi"
             then ./modules/disko/disko-uefi-ext4.nix
             else ./modules/disko/disko-bios-ext4.nix)

            { disko.devices.disk.main.device = disk; }

            (lib.mkIf (firmware == "bios") {
              boot.loader.grub.device = disk;
            })
          ];
      });

    nixosConfigurations =
      (lib.listToAttrs (map mkHost hosts))
      // {
        installer = lib.nixosSystem {
          inherit system;
          specialArgs = { inherit sops-nix nixpkgs; };
          modules = [
            ./hosts/installer/default.nix
          ];
        };
      };
  in
  {
    inherit nixosConfigurations;

    deploy.nodes.sif = {
      hostname = "sif.fiordland-gar.ts.net";
      profiles.system = {
        user = "root";
        path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.sif;
      };
    };

    checks = builtins.mapAttrs
      (system: deployLib: deployLib.deployChecks self.deploy)
      deploy-rs.lib;
  };
}

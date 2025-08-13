{
  description = "Declarative NixOS configuration managed via flakes";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  inputs.disko.url   = "github:nix-community/disko";

  outputs = { self, nixpkgs, disko, ... }:
  let
    lib = nixpkgs.lib;

    hosts = [
      # Bifrost blijft non-disko (we beheren 'm zoals hij nu is)
      { name = "bifrost"; platform = "hetzner"; firmware = "bios"; disk = "/dev/sda"; useDisko = false; }
      # Voor nieuwe hosts zet je useDisko = true en kies je firmware en disk
      # { name = "Thor"; platform = "proxmox"; firmware = "uefi"; disk = "/dev/sda"; useDisko = true; }
    ];

    mkHost = { name, platform, firmware, disk, useDisko ? true }:
      lib.nameValuePair name (nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules =
          [
            ./modules/base.nix
            ./modules/ssh-hardened.nix
            ./modules/users/zanbee.nix
            (if platform == "hetzner" then ./modules/network/hetzner-cloud.nix
                                       else ./modules/network/proxmox-bridge.nix)
            { networking.hostName = name; }
          ]
          ++ (if useDisko then [
                disko.nixosModules.disko
                (if firmware == "uefi" then ./modules/disko-uefi-ext4.nix else ./modules/disko-bios-ext4.nix)
                { disko.devices.disk.main.device = disk; }
                (lib.mkIf (firmware == "bios") { boot.loader.grub.device = disk; })
              ] else [
                # legacy pad: importeer host-specifiek hardware-bestand
                (builtins.toPath ((builtins.toString ./hosts) + "/${name}/default.nix"))
              ]);
      });
  in
  {
    nixosConfigurations = lib.listToAttrs (map mkHost hosts);
  };
}

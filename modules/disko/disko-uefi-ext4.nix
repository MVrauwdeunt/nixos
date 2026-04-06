{ lib, ... }:
{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = lib.mkDefault "/dev/sda";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512MiB"; type = "EF00";
            content = {
              type = "filesystem"; format = "vfat";
              mountpoint = "/boot"; mountOptions = [ "umask=0077" ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "filesystem"; format = "ext4";
              mountpoint = "/"; mountOptions = [ "noatime" ];
            };
          };
        };
      };
    };
  };
  boot.loader.grub = { enable = true; efiSupport = true; device = "nodev"; efiInstallAsRemovable = lib.mkDefault true; };
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault false;
}


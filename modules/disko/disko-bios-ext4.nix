{ lib, ... }:
{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = lib.mkDefault "/dev/sda";
      content = {
        type = "gpt";
        partitions = {
          boot = { size = "1MiB"; type = "EF02"; };
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = [ "noatime" ];
            };
          };
        };
      };
    };
  };
  boot.loader.grub = { enable = true; device = lib.mkDefault "/dev/sda"; };
  fileSystems."/".neededForBoot = true;
}

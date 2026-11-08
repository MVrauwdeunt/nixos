{ ... }:

{
  imports = [
    (import ./common.nix {
      name = "lidarr";
      image = "lscr.io/linuxserver/lidarr:3.1.0.4875-ls45@sha256:d8549ff9ea29b4015c32257360652c1000c31ea471a2b3f0835ae77292faf35b";
      port = 8686;
      tailscaleDefault = true;

      networks = [ "arr-internal" ];
      extraVolumes = [
        "/mnt/shares/Downloads/Muziek:/downloads"
        "/mnt/shares/Media/Muziek:/music"
      ];
    })
  ];
}

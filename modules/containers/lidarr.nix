
{ ... }:

{
  imports = [
    (import ./common.nix {
      name = "lidarr";

      image = "lscr.io/linuxserver/lidarr:3.1.0.4875-ls45@sha256:d8549ff9ea29b4015c32257360652c1000c31ea471a2b3f0835ae77292faf35b";

      port = 8686;
      bindAddress = "127.0.0.1";
      tailscaleDefault = true;

      networks = [ "arr-internal" ];

      directoryOwner = "1000";
      directoryGroup = "1000";

      extraVolumes = [
        "/mnt/shares/Downloads/Muziek:/downloads"
        "/mnt/shares/Media/Muziek:/music"
      ];

      environment = {
        TZ = "Europe/Amsterdam";
        PUID = "1000";
        PGID = "1000";
      };

      extraOptions = [
        "--health-cmd=none"
      ];
    })
  ];
}

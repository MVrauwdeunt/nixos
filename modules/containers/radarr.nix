{ ... }:

{
  imports = [
    (import ./common.nix {
      name = "radarr";
      image = "lscr.io/linuxserver/radarr:6.4.4.10685-ls323@sha256:fc0ae3c50f8128b97e84381903ec8d6845c3a569641cb7117c124376cccb57c1";
      port = 7878;
      tailscaleDefault = true;

      extraVolumes = [
        "/mnt/shares/Downloads/Films:/downloads"
        "/mnt/shares/Media/Films:/media"
      ];
    })
  ];
}

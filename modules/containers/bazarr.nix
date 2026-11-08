{ ... }:

{
  imports = [
    (import ./common.nix {
      name = "bazarr";
      image = "lscr.io/linuxserver/bazarr:v1.6.2-ls369@sha256:946dc8c5bb5331418eac60050cf40a63cb8f66ac039841dda493870e3559799c";
      port = 6767;
      tailscaleDefault = true;

      extraVolumes = [
        "/mnt/shares/Media/Films:/movies"
        "/mnt/shares/Media/Series:/tv"
      ];
    })
  ];
}

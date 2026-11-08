{ ... }:

{
  imports = [
    (import ./common.nix {
      name = "sabnzbd";
      image = "lscr.io/linuxserver/sabnzbd:5.1.3-ls278@sha256:3ac1c9ea03bafa2588dd8acdcb809857bae305e71d2d90e11d689c78076a9c01";
      port = 8081;
      tailscaleDefault = true;

      containerPort = 8080;
      bindAddress = "0.0.0.0";
      extraVolumes = [ "/mnt/shares/Downloads:/downloads" ];
    })
  ];
}

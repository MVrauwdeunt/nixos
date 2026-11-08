{ ... }:

{
  imports = [
    (import ./common.nix {
      name = "newtarr";
      image = "ghcr.io/elfhosted/newtarr:v1.0.0@sha256:6abafe8ee23c96e3c9e298b5f9ef8313f1d231546b794900d4da36caa22912f0";
      port = 9705;
      tailscaleDefault = true;

      bindAddress = "0.0.0.0";
    })
  ];
}

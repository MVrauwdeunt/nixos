{ ... }:

{
  imports = [
    (import ./common.nix {
      name = "profilarr";
      image = "docker.io/santiagosayshey/profilarr:v1.1.5@sha256:8033e9c6d6995f37625afeb93d7020e99566f549ae83b65f1db7e11048952d0f";
      port = 6868;
      tailscaleDefault = true;

      environment.UMASK = "022";
    })
  ];
}

{ ... }:

{
  imports = [
    (import ./common.nix {
      name = "seerr";
      image = "ghcr.io/seerr-team/seerr:v3.5.1@sha256:d8fab675b55ad293ded98fd71efcfd46054cbad9746534ae1cc4794a88c0b3be";
      port = 5055;
      tailscaleDefault = true;

      bindAddress = "0.0.0.0";
      configMount = "/app/config";
      usePuidPgid = false;
      environment.PORT = "5055";
    })
  ];
}

{ ... }:

{
  imports = [
    (import ./common.nix {
      name = "spoolman";
      image = "ghcr.io/donkie/spoolman:0.27.0@sha256:7aba565eff774c6dda212d4204de8fa30bf68d513127ef875cc7ef3197a4664e";
      port = 7912;
      containerPort = 8000;
      configMount = "/home/app/.local/share/spoolman";
      tailscaleDefault = true;
      directoryOwner = "-";
      directoryGroup = "-";
      usePuidPgid = false;
      bridgeNetwork = false;
      disableHealthcheck = false;
    })
  ];
}

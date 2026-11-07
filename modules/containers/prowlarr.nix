
{ ... }:

{
  imports = [
    (import ./common.nix {
      name = "prowlarr";

      image = "lscr.io/linuxserver/prowlarr:2.6.5.5623-ls165@sha256:b3b00047ed20f6ce2b16780145cb6a0acb51c9e28ea6aa6f5dcd33c7034f1797";

      port = 9696;
      tailscaleDefault = true;

      directoryOwner = "1000";
      directoryGroup = "1000";

      environment = {
        TZ = "Europe/Amsterdam";
        PUID = "1000";
        PGID = "1000";
      };

      extraOptions = [
        "--network=bridge"
        "--health-cmd=none"
      ];
    })
  ];
}

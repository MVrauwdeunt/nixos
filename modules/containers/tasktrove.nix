
{ config, lib, ... }:

let
  cfg = config.apps.tasktrove;
in
{
  imports = [
    (import ./common.nix {
      name = "tasktrove";

      image = "ghcr.io/dohsimpson/tasktrove:v0.12.4@sha256:ecfda986ed36909cde78cbdec8b3b39eb60e39be41df3e42afdb102baba9850b";

      port = 3002;
      containerPort = 3000;
      bindAddress = "127.0.0.1";

      dataDir = "/var/lib/tasktrove/data";
      configMount = "/app/data";

      tailscaleDefault = true;

      directoryMode = "0755";
      directoryOwner = "1000";
      directoryGroup = "1000";

      # Behoud de oorspronkelijke Podman-instellingen.
      bridgeNetwork = false;
      disableHealthcheck = false;
    })
  ];

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /var/lib/tasktrove 0755 root root -"
    ];
  };
}

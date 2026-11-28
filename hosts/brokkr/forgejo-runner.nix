
{ config, pkgs, ... }:

let
  runnerUser = "forgejo-runner";
  runnerHome = "/var/lib/forgejo-runner";
  runtimeDir = "/run/user/1001";
  podmanSocket = "/run/forgejo-podman/podman.sock";

  runnerConfig = pkgs.writeText "forgejo-runner.yaml" ''
    log:
      level: info

    runner:
      capacity: 1
      timeout: 3h

    cache:
      enabled: false

    container:
      network: ""
      enable_ipv6: false
      privileged: false
      valid_volumes: []
      docker_host: "-"
      force_pull: true
  '';
in
{
  environment.systemPackages = [
    pkgs.forgejo-runner
  ];

  # Rootless Podman API.
  systemd.services.forgejo-podman = {
    description = "Rootless Podman API for Forgejo Runner";

    wantedBy = [ "multi-user.target" ];
    requires = [ "user@1001.service" ];
    after = [ "user@1001.service" ];

    environment = {
      HOME = runnerHome;
      XDG_RUNTIME_DIR = runtimeDir;
    };

    path = [
      pkgs.podman
      pkgs.passt
    ];

    serviceConfig = {
      User = runnerUser;
      Group = runnerUser;

      RuntimeDirectory = "forgejo-podman";
      RuntimeDirectoryMode = "0700";

      WorkingDirectory = runnerHome;

      ExecStart = "${pkgs.podman}/bin/podman system service --time=0 unix://${podmanSocket}";

      Delegate = true;
      Restart = "on-failure";
      RestartSec = 5;
      UMask = "0077";
    };
  };

  # Forgejo Runner daemon.
  systemd.services.forgejo-runner = {
    description = "Brokkr Forgejo CI Runner";

    wantedBy = [ "multi-user.target" ];

    requires = [
      "forgejo-podman.service"
    ];

    wants = [
      "network-online.target"
      "tailscaled.service"
      "dnsmasq.service"
    ];

    after = [
      "network-online.target"
      "tailscaled.service"
      "dnsmasq.service"
      "forgejo-podman.service"
    ];

    environment = {
      HOME = runnerHome;
      XDG_RUNTIME_DIR = runtimeDir;
      DOCKER_HOST = "unix://${podmanSocket}";
    };

    path = [
      pkgs.git
      pkgs.podman
      pkgs.cacert
    ];

    serviceConfig = {
      User = runnerUser;
      Group = runnerUser;

      WorkingDirectory = runnerHome;

      LoadCredential = [
        "runner-token:${config.sops.secrets.forgejoRunnerToken.path}"
      ];

      ExecStart = ''
        ${pkgs.forgejo-runner}/bin/forgejo-runner daemon \
          --config ${runnerConfig} \
          --url https://forgejo.fiordland-gar.ts.net/ \
          --uuid 2f6ef0fa-7d87-4cf3-86b7-c98923e3dbce \
          --token-url file://%d/runner-token \
          --label brokkr:docker://docker.io/library/node:24-bookworm
      '';

      Restart = "on-failure";
      RestartSec = 10;

      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;

      ReadWritePaths = [
        runnerHome
      ];
    };
  };
}

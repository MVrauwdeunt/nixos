
{ config, pkgs, ... }:

let
  runnerUser = "forgejo-runner";
  runnerHome = "/var/lib/forgejo-runner";
  runtimeDir = "/run/user/1001";
  podmanSocket = "${runtimeDir}/forgejo-podman.sock";

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

  # Rootless Podman API within the delegated user cgroup.
  systemd.user.services.forgejo-podman = {
    description = "Rootless Podman API for Forgejo Runner";

    wantedBy = [ "default.target" ];

    unitConfig = {
      ConditionUser = runnerUser;
    };

    environment = {
      HOME = runnerHome;
      XDG_RUNTIME_DIR = runtimeDir;
    };

    path = [
      pkgs.podman
      pkgs.passt
    ];

    serviceConfig = {
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
      "user@1001.service"
    ];

    wants = [
      "network-online.target"
      "tailscaled.service"
      "dnsmasq.service"
    ];

    after = [
      "user@1001.service"
      "network-online.target"
      "tailscaled.service"
      "dnsmasq.service"
    ];

    environment = {
      HOME = runnerHome;
      XDG_RUNTIME_DIR = runtimeDir;
      DBUS_SESSION_BUS_ADDRESS = "unix:path=${runtimeDir}/bus";
      DOCKER_HOST = "unix://${podmanSocket}";
    };

    path = [
      pkgs.git
      pkgs.podman
      pkgs.cacert
      pkgs.systemd
    ];

    # Start the user service and wait for its API.
    preStart = ''
      systemctl --user start forgejo-podman.service

      for attempt in $(seq 1 30); do
        if podman --remote --url unix://${podmanSocket} info >/dev/null 2>&1; then
          exit 0
        fi
        sleep 1
      done

      echo "Rootless Podman API is unavailable"
      exit 1
    '';

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
          --label brokkr:docker://docker.io/library/node:24-bookworm \
          --label nixos:docker://docker.io/library/node:24-bookworm
      '';

      Restart = "on-failure";
      RestartSec = 10;

      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";

      InaccessiblePaths = [
        "/home"
        "/root"
      ];

      ReadWritePaths = [
        runnerHome
      ];
    };
  };
}


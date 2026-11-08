{ config, lib, ... }:
let cfg = config.apps.renovate;
in {
  imports = [ (import ./common.nix {
    name = "renovate";
    image = cfg.image;
    port = 3000;
    publishedPorts = [ ];
    dataDir = "/var/lib/renovate";
    configMount = "/tmp/renovate";
    directoryMode = "0750";
    directoryOwner = "12021";
    directoryGroup = "root";
    useTimezone = false;
    usePuidPgid = false;
    bridgeNetwork = false;
    disableHealthcheck = false;
    environment = {
      LOG_LEVEL = cfg.logLevel;
      TZ = cfg.timezone;
      RENOVATE_PLATFORM = "forgejo";
      RENOVATE_ENDPOINT = "http://127.0.0.1:3000/api/v1/";
      RENOVATE_REPOSITORIES = lib.concatStringsSep "," cfg.repositories;
      RENOVATE_BASE_DIR = "/tmp/renovate";
    };
    extraOptions = [ "--hostname=renovate" "--userns=host" "--network=host" ];
  }) ];

  options.apps.renovate = {
    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/renovate/renovate:43.139-full@sha256:c1c399fa676f11258937cb708f6e40fb6659de7e62600b21e7fc2796eb450754";
    };
    tokenEnvFile = lib.mkOption { type = lib.types.path; default = "/run/secrets/renovate-env"; };
    repositories = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ "zanbee/nixos" ]; };
    timezone = lib.mkOption { type = lib.types.str; default = "Europe/Amsterdam"; };
    logLevel = lib.mkOption {
      type = lib.types.enum [ "trace" "debug" "info" "warn" "error" "fatal" ];
      default = "info";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";
    virtualisation.oci-containers.containers.renovate = {
      autoStart = false;
      environmentFiles = [ cfg.tokenEnvFile ];
    };
    systemd.tmpfiles.rules = [ "z ${cfg.dataDir} 0750 12021 root - -" ];
    systemd.services.podman-renovate = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig.Restart = lib.mkForce "no";
    };
    systemd.timers.podman-renovate = {
      description = "Daily Renovate dependency scan";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "30m";
        Unit = "podman-renovate.service";
      };
    };
  };
}

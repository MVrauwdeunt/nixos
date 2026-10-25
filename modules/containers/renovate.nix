
{ config, lib, ... }:

with lib;

let
  cfg = config.apps.renovate;
in
{
  options.apps.renovate = {
    enable = mkEnableOption "Renovate bot container";

    tailscale.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Expose Renovate through Tailscale Serve.";
    };

    image = mkOption {
      type = types.str;
      default = "docker.io/renovate/renovate:43.139-full@sha256:c1c399fa676f11258937cb708f6e40fb6659de7e62600b21e7fc2796eb450754";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/renovate";
    };

    tokenEnvFile = mkOption {
      type = types.path;
      default = "/run/secrets/renovate-env";
    };

    repositories = mkOption {
      type = types.listOf types.str;
      default = [ "zanbee/nixos" ];
    };

    timezone = mkOption {
      type = types.str;
      default = "Europe/Amsterdam";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Renovate has no web UI.";
    };

    logLevel = mkOption {
      type = types.enum [
        "trace"
        "debug"
        "info"
        "warn"
        "error"
        "fatal"
      ];
      default = "info";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 12021 root - -"
      "z ${cfg.dataDir} 0750 12021 root - -"
    ];

    virtualisation.oci-containers.containers.renovate = {
      image = cfg.image;
      pull = "missing";

      # Renovate is a batch job, not a daemon.
      autoStart = false;

      environment = {
        LOG_LEVEL = cfg.logLevel;
        TZ = cfg.timezone;

        RENOVATE_PLATFORM = "forgejo";
        RENOVATE_ENDPOINT = "http://127.0.0.1:3000/api/v1/";
        RENOVATE_REPOSITORIES =
          concatStringsSep "," cfg.repositories;
        RENOVATE_BASE_DIR = "/tmp/renovate";
      };

      environmentFiles = [
        cfg.tokenEnvFile
      ];

      volumes = [
        "${cfg.dataDir}:/tmp/renovate"
      ];

      # No custom shell wrapper or token-bearing Git URL rewrites.

      extraOptions = [
        "--hostname=renovate"
        "--userns=host"
        "--network=host"
      ];
    };

    systemd.services.podman-renovate = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig.Restart = mkForce "no";
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

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.apps.renovate;
in
{
  options.apps.renovate = {
    enable = mkEnableOption "Renovate bot container";

    image = mkOption {
      type = types.str;
      default = "docker.io/renovate/renovate:latest";
      description = "Container image for Renovate";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/renovate";
      description = "Persistent data directory for Renovate";
    };

    configFile = mkOption {
      type = types.path;
      default = "/run/secrets/renovate-config.js";
      description = "Path to the self-hosted Renovate config file";
    };

    tokenEnvFile = mkOption {
      type = types.path;
      default = "/run/secrets/renovate-env";
      description = "Env file containing RENOVATE_TOKEN=...";
    };

    endpoint = mkOption {
      type = types.str;
      default = "https://forgejo.fiordland-gar.ts.net/api/v1/";
      description = "Forgejo API endpoint";
    };

    repositories = mkOption {
      type = types.listOf types.str;
      default = [ "zanbee/nixos" ];
      description = "Repositories Renovate should manage";
    };

    timezone = mkOption {
      type = types.str;
      default = "Europe/Amsterdam";
      description = "Timezone for Renovate";
    };

    schedule = mkOption {
      type = types.listOf types.str;
      default = [ "after 02:00 and before 05:00 on saturday" ];
      description = "Renovate schedule";
    };

    logLevel = mkOption {
      type = types.enum [ "trace" "debug" "info" "warn" "error" "fatal" ];
      default = "info";
      description = "Renovate log level";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 root root - -"
    ];

    virtualisation.oci-containers.containers.renovate = {
      image = cfg.image;
      autoStart = true;

      environment = {
        LOG_LEVEL = cfg.logLevel;
        TZ = cfg.timezone;
        RENOVATE_PLATFORM = "forgejo";
        RENOVATE_ENDPOINT = cfg.endpoint;
        RENOVATE_CONFIG_FILE = "/config/config.js";
        RENOVATE_REPOSITORIES = concatStringsSep "," cfg.repositories;
      };

      volumes = [
        "${cfg.dataDir}:/tmp/renovate"
        "${cfg.configFile}:/config/config.js:ro"
        "${cfg.tokenEnvFile}:/run/secrets/renovate-env:ro"
      ];

      environmentFiles = [
        cfg.tokenEnvFile
      ];

      extraOptions = [
        "--pull=always"
        "--hostname=renovate"
        "--userns=host"
      ];
    };

    systemd.services.podman-renovate.after = [ "network-online.target" ];
    systemd.services.podman-renovate.wants = [ "network-online.target" ];
  };
}
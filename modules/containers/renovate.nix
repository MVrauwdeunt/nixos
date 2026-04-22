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
      default = "docker.io/renovate/renovate:43.139-full";
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
        RENOVATE_PLATFORM = "gitea";
        RENOVATE_ENDPOINT = cfg.endpoint;
        RENOVATE_REPOSITORIES = concatStringsSep "," cfg.repositories;

        RENOVATE_USERNAME = "zanbee";
      };

      volumes = [
        "${cfg.dataDir}:/tmp/renovate"
        "${cfg.tokenEnvFile}:/run/secrets/renovate-env:ro"
        "${cfg.configFile}:/config/config.js:ro"
      ];

      environmentFiles = [
        cfg.tokenEnvFile
      ];

      extraOptions = [
        "--hostname=renovate"
        "--userns=host"
      ];
    };

    systemd.services.podman-renovate.after = [ "network-online.target" ];
    systemd.services.podman-renovate.wants = [ "network-online.target" ];
  };
}
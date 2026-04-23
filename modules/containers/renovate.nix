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

    logLevel = mkOption {
      type = types.enum [ "trace" "debug" "info" "warn" "error" "fatal" ];
      default = "debug";
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
        RENOVATE_ENDPOINT = "http://127.0.0.1:3000/api/v1/";
        RENOVATE_REPOSITORIES = concatStringsSep "," cfg.repositories;
      };

      environmentFiles = [
        cfg.tokenEnvFile
      ];

      volumes = [
        "${cfg.dataDir}:/tmp/renovate"
      ];

      cmd = [
        "/bin/sh"
        "-lc"
        ''
          set -eu

          TOKEN="$(sed -n 's/^RENOVATE_TOKEN=//p' ${cfg.tokenEnvFile})"

          git config --global url."http://zanbee:$TOKEN@127.0.0.1:3000/".insteadOf "https://forgejo.fiordland-gar.ts.net/"
          git config --global url."http://zanbee:$TOKEN@127.0.0.1:3000/".insteadOf "https://$TOKEN@forgejo.fiordland-gar.ts.net/"

          exec renovate
        ''
      ];

      extraOptions = [
        "--hostname=renovate"
        "--userns=host"
        "--network=host"
      ];
    };

    systemd.services.podman-renovate.after = [ "network-online.target" ];
    systemd.services.podman-renovate.wants = [ "network-online.target" ];
  };
}
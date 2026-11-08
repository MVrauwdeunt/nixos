
{ config, lib, ... }:

let
  cfg = config.apps.allos;

  defaultImage =
    "ghcr.io/floorlamp/allos:9cc16e0c1cae35406ba29ffc754f8f921d64d90c@sha256:4562e9ec3be77538e7759b3f59fdd48fa1b564407ecdc6c3e86f151c5c1766db";

  backupVolumes = lib.optionals (cfg.backupDir != null) [
    "${cfg.backupDir}:/backup"
  ];

  commonEnvironment = {
    NODE_ENV = "production";
  } // lib.optionalAttrs (cfg.backupDir != null) {
    BACKUP_DEST_DIR = "/backup";
  };

  commonOptions = [
    "--security-opt=no-new-privileges"
    "--stop-timeout=30"
  ];
in
{
  imports = [
    (import ./common.nix {
      name = "allos";
      image = cfg.image;

      port = 3006;
      containerPort = 3000;
      bindAddress = "127.0.0.1";

      configMount = "/app/data";
      tailscaleDefault = true;

      directoryMode = "0700";
      directoryOwner = "root";
      directoryGroup = "root";

      useTimezone = false;
      usePuidPgid = false;
      bridgeNetwork = false;
      disableHealthcheck = false;

      extraVolumes = backupVolumes;
      environment = commonEnvironment;
      extraOptions = commonOptions;
    })

    (import ./common.nix {
      name = "allos-notify";
      image = cfg.image;

      port = 3000;
      publishedPorts = [ ];

      dataDir = cfg.dataDir;
      configMount = "/app/data";
      createDataDir = false;

      useTimezone = false;
      usePuidPgid = false;
      bridgeNetwork = false;
      disableHealthcheck = false;

      extraVolumes = backupVolumes;
      environment = commonEnvironment;
      extraOptions = commonOptions;
    })
  ];

  options.apps.allos = {
    image = lib.mkOption {
      type = lib.types.str;
      default = defaultImage;
      description = "Allos container image pinned to a commit and SHA256 digest.";
    };

    backupDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional Allos backup directory.";
    };

    adminUsername = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Bootstrap admin username.";
    };

    notifications.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Allos notification worker.";
    };

    tailscale.serviceName = lib.mkOption {
      type = lib.types.str;
      default = "health";
      description = "Tailscale Service name.";
    };
  };

  config = lib.mkMerge [
    {
      apps.allos-notify.enable =
        cfg.enable && cfg.notifications.enable;
    }

    (lib.mkIf cfg.enable {
      virtualisation.oci-containers.backend = "podman";

      sops.secrets."saga/allos_admin_password" = {};

      sops.templates."allos-bootstrap.env".content = ''
        ADMIN_USERNAME=${cfg.adminUsername}
        ADMIN_PASSWORD=${config.sops.placeholder."saga/allos_admin_password"}
      '';

      virtualisation.oci-containers.containers.allos.environmentFiles = [
        config.sops.templates."allos-bootstrap.env".path
      ];

      systemd.tmpfiles.rules =
        lib.optionals (cfg.backupDir != null) [
          "d ${cfg.backupDir} 0700 root root - -"
        ];

      systemd.services.podman-allos = {
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
      };
    })

    (lib.mkIf (cfg.enable && cfg.notifications.enable) {
      virtualisation.oci-containers.containers.allos-notify = {
        cmd = [ "docker-notify.sh" ];
        dependsOn = [ "allos" ];
      };
    })
  ];
}

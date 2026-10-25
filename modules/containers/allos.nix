{ config, lib, ... }:

let
  cfg = config.apps.allos;

  commonEnvironment = {
    NODE_ENV = "production";
  } // lib.optionalAttrs (cfg.backupDir != null) {
    BACKUP_DEST_DIR = "/backup";
  };

  commonVolumes =
    [ "${cfg.dataDir}:/app/data" ]
    ++ lib.optionals (cfg.backupDir != null) [
      "${cfg.backupDir}:/backup"
    ];

in
{
  options.apps.allos = {
    enable = lib.mkEnableOption "Allos health manager";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/floorlamp/allos:9cc16e0c1cae35406ba29ffc754f8f921d64d90c@sha256:4562e9ec3be77538e7759b3f59fdd48fa1b564407ecdc6c3e86f151c5c1766db";
      description = "Allos container image pinned to a commit and SHA256 digest.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3006;
      description = "Local HTTP port for Allos.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/allos";
      description = "Persistent Allos data directory.";
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

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the Allos HTTP port in the firewall.";
    };

    tailscale = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Expose Allos through Tailscale Services.";
      };

      serviceName = lib.mkOption {
        type = lib.types.str;
        default = "health";
        description = "Tailscale Service name.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";

    sops.secrets."saga/allos_admin_password" = {};

    sops.templates."allos-bootstrap.env".content = ''
      ADMIN_USERNAME=${cfg.adminUsername}
      ADMIN_PASSWORD=${config.sops.placeholder."saga/allos_admin_password"}
    '';

    systemd.tmpfiles.rules =
      [ "d ${cfg.dataDir} 0700 root root - -" ]
      ++ lib.optionals (cfg.backupDir != null) [
        "d ${cfg.backupDir} 0700 root root - -"
      ];

    virtualisation.oci-containers.containers = {
      allos = {
        image = cfg.image;
        pull = "missing";
        autoStart = true;

        ports = [
          "127.0.0.1:${toString cfg.port}:3000"
        ];

        volumes = commonVolumes;

        environment = commonEnvironment;

        environmentFiles = [
          config.sops.templates."allos-bootstrap.env".path
        ];

        extraOptions = [
          "--security-opt=no-new-privileges"
          "--stop-timeout=30"
        ];
      };
    } // lib.optionalAttrs cfg.notifications.enable {
      allos-notify = {
        image = cfg.image;
        pull = "missing";
        autoStart = true;

        cmd = [
          "docker-notify.sh"
        ];

        dependsOn = [
          "allos"
        ];

        volumes = commonVolumes;

        environment = commonEnvironment;

        extraOptions = [
          "--security-opt=no-new-privileges"
          "--stop-timeout=30"
        ];
      };
    };

    systemd.services.podman-allos = {
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
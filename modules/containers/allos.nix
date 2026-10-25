
{ config, lib, ... }:

let
  cfg = config.apps.allos;

  commonEnvironment = {
    NODE_ENV = "production";
  } // lib.optionalAttrs (cfg.backupDir != null) {
    BACKUP_DEST_DIR = "/backup";
  };

  commonVolumes = [
    "${cfg.dataDir}:/app/data"
  ] ++ lib.optionals (cfg.backupDir != null) [
    "${cfg.backupDir}:/backup"
  ];

in
{
  options.apps.allos = {
    enable = lib.mkEnableOption "Allos health manager";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/floorlamp/allos:9cc16e0c1cae35406ba29ffc754f8f921d64d90c@sha256:4562e9ec3be77538e7759b3f59fdd48fa1b564407ecdc6c3e86f151c5c1766db";
      description = "Allos container image pinned to Git revision and SHA256 digest.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3006;
      description = "Local Allos web UI port.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/allos";
      description = "Persistent Allos data directory.";
    };

    backupDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional external backup directory.";
    };

    adminUsername = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Initial administrator username.";
    };

    notifications.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable notification and backup scheduler.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open Allos port in the firewall.";
    };

    tailscale = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Expose Allos via Tailscale Serve.";
      };

      serviceName = lib.mkOption {
        type = lib.types.str;
        default = "health";
        description = "Tailscale service name (svc:health).";
      };
    };
  };

  config = lib.mkIf cfg.enable {

    #
    # Podman
    #

    virtualisation.oci-containers.backend = "podman";

    #
    # SOPS - administrator credentials
    #

    sops.secrets."saga/allos_admin_password" = {};

    sops.templates."allos-bootstrap.env".content = ''
      ADMIN_USERNAME=${cfg.adminUsername}
      ADMIN_PASSWORD=${config.sops.placeholder."saga/allos_admin_password"}
    '';

    #
    # Persistent storage
    #

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0700 root root - -"
    ] ++ lib.optionals (cfg.backupDir != null) [
      "d ${cfg.backupDir} 0700 root root - -"
    ];

    #
    # Containers
    #

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

          # Official Allos HTTP healthcheck
          "--health-cmd=node -e \"fetch('http://localhost:3000/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))\""
          "--health-interval=30s"
          "--health-timeout=5s"
          "--health-retries=3"
          "--health-start-period=30s"
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
        ];
      };
    };

    #
    # Systemd
    #

    systemd.services.podman-allos = {
      wants = [
        "network-online.target"
      ];

      after = [
        "network-online.target"
      ];
    };

    #
    # Firewall
    #

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}

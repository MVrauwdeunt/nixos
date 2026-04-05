{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.apps.unifi;
in
{
  options.apps.unifi = {
    enable = mkEnableOption "UniFi Network Application container stack";

    image = mkOption {
      type = types.str;
      default = "lscr.io/linuxserver/unifi-network-application:latest";
      description = "Container image for UniFi Network Application";
    };

    mongoImage = mkOption {
      type = types.str;
      default = "docker.io/mongo:8.0";
      description = "MongoDB container image";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/unifi";
      description = "Base data directory for UniFi";
    };

    uid = mkOption {
      type = types.int;
      default = 1000;
      description = "UID used inside the UniFi container";
    };

    gid = mkOption {
      type = types.int;
      default = 1000;
      description = "GID used inside the UniFi container";
    };

    timezone = mkOption {
      type = types.str;
      default = "Europe/Amsterdam";
      description = "Timezone for the containers";
    };

    mongoDbName = mkOption {
      type = types.str;
      default = "unifi";
      description = "MongoDB database name";
    };

    mongoUser = mkOption {
      type = types.str;
      default = "unifi";
      description = "MongoDB username";
    };

    mongoPassword = mkOption {
      type = types.str;
      default = "changeme";
      description = "MongoDB password";
    };

    memLimit = mkOption {
      type = types.str;
      default = "1024";
      description = "JVM memory limit for UniFi";
    };

    memStartup = mkOption {
      type = types.str;
      default = "1024";
      description = "JVM startup memory for UniFi";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open UniFi ports in the firewall";
    };

    hostAddress = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional hostname or IP to use later as Inform Host";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root - -"
      "d ${cfg.dataDir}/config 0755 ${toString cfg.uid} ${toString cfg.gid} - -"
      "d ${cfg.dataDir}/mongo 0755 999 999 - -"
    ];

    virtualisation.oci-containers.containers = {
      unifi-db = {
        image = cfg.mongoImage;
        autoStart = true;

        environment = {
          MONGO_INITDB_ROOT_USERNAME = cfg.mongoUser;
          MONGO_INITDB_ROOT_PASSWORD = cfg.mongoPassword;
        };

        volumes = [
          "${cfg.dataDir}/mongo:/data/db"
        ];

        extraOptions = [
          "--hostname=unifi-db"
          "--network=bridge"
        ];
      };

      unifi = {
        image = cfg.image;
        autoStart = true;

        dependsOn = [ "unifi-db" ];

        environment = {
          PUID = toString cfg.uid;
          PGID = toString cfg.gid;
          TZ = cfg.timezone;

          MONGO_USER = cfg.mongoUser;
          MONGO_PASS = cfg.mongoPassword;
          MONGO_HOST = "unifi-db";
          MONGO_PORT = "27017";
          MONGO_DBNAME = cfg.mongoDbName;

          MEM_LIMIT = cfg.memLimit;
          MEM_STARTUP = cfg.memStartup;
        };

        volumes = [
          "${cfg.dataDir}/config:/config"
        ];

        ports = [
          "8443:8443"
          "8080:8080"
          "3478:3478/udp"
          "10001:10001/udp"
          # optioneel, afhankelijk van gebruik:
          "1900:1900/udp"
          "8843:8843"
          "8880:8880"
          "6789:6789"
          "5514:5514/udp"
        ];

        extraOptions = [
          "--hostname=unifi"
          "--network=bridge"
        ];
      };
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ 8443 8080 8843 8880 6789 ];
      allowedUDPPorts = [ 3478 10001 1900 5514 ];
    };

    systemd.services.podman-unifi = {
      after = [ "network-online.target" "podman-unifi-db.service" ];
      wants = [ "network-online.target" ];
      requires = [ "podman-unifi-db.service" ];
    };

    systemd.services.podman-unifi-db = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
    };
  };
}

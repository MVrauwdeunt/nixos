{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.apps.unifi;

  initMongoScript = pkgs.writeText "init-mongo.sh" ''
    #!/bin/bash

    if which mongosh > /dev/null 2>&1; then
      mongo_init_bin='mongosh'
    else
      mongo_init_bin='mongo'
    fi

    "${mongo_init_bin}" <<EOF
    use ${cfg.mongoAuthSource}
    db.auth("${cfg.mongoRootUser}", "${cfg.mongoRootPassword}")
    db.createUser({
      user: "${cfg.mongoUser}",
      pwd: "${cfg.mongoPassword}",
      roles: [
        { db: "${cfg.mongoDbName}", role: "dbOwner" },
        { db: "${cfg.mongoDbName}_stat", role: "dbOwner" },
        { db: "${cfg.mongoDbName}_audit", role: "dbOwner" }
      ]
    })
    EOF
  '';
in
{
  options.apps.unifi = {
    enable = mkEnableOption "UniFi Network Application container stack";

    image = mkOption {
      type = types.str;
      default = "lscr.io/linuxserver/unifi-network-application:10.1.89";
    };

    mongoImage = mkOption {
      type = types.str;
      default = "docker.io/mongo:8.0";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/unifi";
    };

    uid = mkOption {
      type = types.int;
      default = 1000;
    };

    gid = mkOption {
      type = types.int;
      default = 1000;
    };

    timezone = mkOption {
      type = types.str;
      default = "Europe/Amsterdam";
    };

    mongoDbName = mkOption {
      type = types.str;
      default = "unifi";
    };

    mongoUser = mkOption {
      type = types.str;
      default = "unifi";
    };

    mongoPassword = mkOption {
      type = types.str;
      default = "changeme";
    };

    mongoRootUser = mkOption {
      type = types.str;
      default = "root";
    };

    mongoRootPassword = mkOption {
      type = types.str;
      default = "changeme-root";
    };

    mongoAuthSource = mkOption {
      type = types.str;
      default = "admin";
    };

    memLimit = mkOption {
      type = types.str;
      default = "1024";
    };

    memStartup = mkOption {
      type = types.str;
      default = "1024";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
    };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root - -"
      "d ${cfg.dataDir}/config 0755 root root - -"
      "d ${cfg.dataDir}/mongo 0755 root root - -"
    ];

    virtualisation.oci-containers.containers = {
      unifi-db = {
        image = cfg.mongoImage;
        autoStart = true;

        environment = {
          MONGO_INITDB_ROOT_USERNAME = cfg.mongoRootUser;
          MONGO_INITDB_ROOT_PASSWORD = cfg.mongoRootPassword;
          MONGO_USER = cfg.mongoUser;
          MONGO_PASS = cfg.mongoPassword;
          MONGO_DBNAME = cfg.mongoDbName;
          MONGO_AUTHSOURCE = cfg.mongoAuthSource;
        };

        volumes = [
          "${cfg.dataDir}/mongo:/data/db"
          "${initMongoScript}:/docker-entrypoint-initdb.d/init-mongo.sh:ro"
        ];

        extraOptions = [
          "--hostname=unifi-db"
          "--network=podman"
          "--network-alias=unifi-db"
          "--userns=host"
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
          MONGO_AUTHSOURCE = cfg.mongoAuthSource;

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
          "1900:1900/udp"
          "8843:8843"
          "8880:8880"
          "6789:6789"
          "5514:5514/udp"
        ];

        extraOptions = [
          "--hostname=unifi"
          "--network=podman"
          "--userns=host"
        ];
      };
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ 8443 8080 8843 8880 6789 ];
      allowedUDPPorts = [ 3478 10001 1900 5514 ];
    };
  };
}

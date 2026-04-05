{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.apps.unifi;

  initMongoScript = pkgs.writeText "init-mongo.sh" ''
    #!/bin/sh
    set -eu

    if command -v mongosh >/dev/null 2>&1; then
      mongo_init_bin="mongosh"
    else
      mongo_init_bin="mongo"
    fi

    "$mongo_init_bin" <<EOF
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

    mongoRootUser = mkOption {
      type = types.str;
      default = "root";
      description = "MongoDB root username";
    };

    mongoRootPassword = mkOption {
      type = types.str;
      default = "changeme-root";
      description = "MongoDB root password";
    };

    mongoAuthSource = mkOption {
      type = types.str;
      default = "admin";
      description = "MongoDB auth source";
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
        };

        volumes = [
          "${cfg.dataDir}/mongo:/data/db"
          "${initMongoScript}:/docker-entrypoint-initdb.d/init-mongo.sh:ro"
        ];

        extraOptions = [
          "--hostname=unifi-db"
          "--network=host"
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
          MONGO_HOST = "127.0.0.1";
          MONGO_PORT = "27017";
          MONGO_DBNAME = cfg.mongoDbName;
          MONGO_AUTHSOURCE = cfg.mongoAuthSource;

          MEM_LIMIT = cfg.memLimit;
          MEM_STARTUP = cfg.memStartup;
        };

        volumes = [
          "${cfg.dataDir}/config:/config"
        ];

        extraOptions = [
          "--hostname=unifi"
          "--network=host"
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

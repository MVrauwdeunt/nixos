{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.apps.netalertx;
in
{
  options.apps.netalertx = {
    enable = mkEnableOption "NetAlertX container stack";

    image = mkOption {
      type = types.str;
      default = "ghcr.io/jokob-sk/netalertx:25.11";
      description = "Container image for NetAlertX";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/netalertx";
      description = "Persistent data directory for NetAlertX";
    };

    uid = mkOption {
      type = types.int;
      default = 20211;
      description = "UID used inside the NetAlertX container";
    };

    gid = mkOption {
      type = types.int;
      default = 20211;
      description = "GID used inside the NetAlertX container";
    };

    timezone = mkOption {
      type = types.str;
      default = "Europe/Amsterdam";
      description = "Timezone for the container";
    };

    port = mkOption {
      type = types.port;
      default = 20211;
      description = "Web UI port";
    };

    graphqlPort = mkOption {
      type = types.port;
      default = 20212;
      description = "GraphQL port";
    };

    debug = mkOption {
      type = types.int;
      default = 0;
      description = "Debug level";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open NetAlertX ports in the host firewall";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";

    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
        flags = [ "--all" ];
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${toString cfg.uid} ${toString cfg.gid} - -"
      "d ${cfg.dataDir}/db 0755 ${toString cfg.uid} ${toString cfg.gid} - -"
      "d ${cfg.dataDir}/config 0755 ${toString cfg.uid} ${toString cfg.gid} - -"
      "f ${cfg.dataDir}/config/app.conf 0644 ${toString cfg.uid} ${toString cfg.gid} - -"
    ];

    virtualisation.oci-containers.containers.netalertx = {
      image = cfg.image;
      autoStart = true;

      environment = {
        TZ = cfg.timezone;
        PUID = toString cfg.uid;
        PGID = toString cfg.gid;
        PORT = toString cfg.port;
        GRAPHQL_PORT = toString cfg.graphqlPort;
        ALWAYS_FRESH_INSTALL = "false";
        NETALERTX_DEBUG = toString cfg.debug;
      };

      volumes = [
        "${cfg.dataDir}:/data"
        "/etc/localtime:/etc/localtime:ro"
      ];

      extraOptions = [
        "--network=host"
        "--hostname=netalertx"
        "--userns=host"

        "--cap-drop=ALL"
        "--cap-add=NET_ADMIN"
        "--cap-add=NET_RAW"
        "--cap-add=NET_BIND_SERVICE"

        "--tmpfs=/tmp:rw,noexec,nosuid,size=64m"
        "--tmpfs=/run:rw,noexec,nosuid,size=16m"

        "--memory=2048m"
        "--memory-reservation=1024m"
        "--cpus=0.5"
        "--pids-limit=512"

        "--security-opt=no-new-privileges"
      ];
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port cfg.graphqlPort ];
    };

    systemd.services.podman-netalertx.after = [ "network-online.target" ];
    systemd.services.podman-netalertx.wants = [ "network-online.target" ];
  };
}

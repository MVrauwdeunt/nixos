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

    tailscaleImage = mkOption {
      type = types.str;
      default = "docker.io/tailscale/tailscale:stable";
      description = "Container image for the Tailscale sidecar";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/netalertx";
      description = "Persistent data directory for NetAlertX";
    };

    tailscaleStateDir = mkOption {
      type = types.path;
      default = "/var/lib/tailscale-netalertx";
      description = "Persistent state directory for the Tailscale sidecar";
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

    tailscaleHostname = mkOption {
      type = types.str;
      default = "netalertx";
      description = "Hostname used by the Tailscale sidecar";
    };

    tailscaleAuthFile = mkOption {
      type = types.path;
      description = "Path to an env file containing Tailscale OAuth credentials";
    };

    tailscaleAdvertiseTags = mkOption {
      type = types.listOf types.str;
      default = [ "tag:container" ];
      description = "Tags advertised by the Tailscale sidecar";
    };

    userspaceNetworking = mkOption {
      type = types.bool;
      default = false;
      description = "Use Tailscale userspace networking instead of /dev/net/tun";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open NetAlertX ports in the host firewall";
    };

    serveConfigFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to a JSON file for Tailscale Serve configuration";
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
        flags = [ "--all" ];
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${toString cfg.uid} ${toString cfg.gid} - -"
      "d ${cfg.dataDir}/db 0755 ${toString cfg.uid} ${toString cfg.gid} - -"
      "d ${cfg.dataDir}/config 0755 ${toString cfg.uid} ${toString cfg.gid} - -"
      "f ${cfg.dataDir}/config/app.conf 0644 ${toString cfg.uid} ${toString cfg.gid} - -"

      "d ${cfg.tailscaleStateDir} 0755 root root - -"
    ];

    virtualisation.oci-containers.containers = {
      tailscale-netalertx = {
        image = cfg.tailscaleImage;
        autoStart = true;

        environment =
          {
            TS_HOSTNAME = cfg.tailscaleHostname;
            TS_STATE_DIR = "/var/lib/tailscale";
            TS_USERSPACE = if cfg.userspaceNetworking then "true" else "false";
            TS_EXTRA_ARGS = "--advertise-tags=${concatStringsSep "," cfg.tailscaleAdvertiseTags}";
          }
          // optionalAttrs (cfg.serveConfigFile != null) {
            TS_SERVE_CONFIG = "/config/serve.json";
          };

        environmentFiles = [
          cfg.tailscaleAuthFile
        ];

        volumes =
          [
            "${cfg.tailscaleStateDir}:/var/lib/tailscale"
          ]
          ++ optionals (cfg.serveConfigFile != null) [
            "${cfg.serveConfigFile}:/config/serve.json:ro"
          ];

        extraOptions =
          [
            "--hostname=tailscale-netalertx"
            "--network=bridge"
            "--userns=host"
          ]
          ++ optionals (!cfg.userspaceNetworking) [
            "--cap-add=NET_ADMIN"
            "--cap-add=NET_RAW"
            "--device=/dev/net/tun"
          ];
      };

      netalertx = {
        image = cfg.image;
        autoStart = true;
        dependsOn = [ "tailscale-netalertx" ];

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
          "--hostname=netalertx"
          "--network=container:tailscale-netalertx"
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
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port cfg.graphqlPort ];
    };

    systemd.services.podman-netalertx.after = [
      "network-online.target"
      "podman-tailscale-netalertx.service"
    ];
    systemd.services.podman-netalertx.wants = [ "network-online.target" ];
    systemd.services.podman-netalertx.requires = [ "podman-tailscale-netalertx.service" ];

    systemd.services.podman-tailscale-netalertx.after = [ "network-online.target" ];
    systemd.services.podman-tailscale-netalertx.wants = [ "network-online.target" ];
  };
}

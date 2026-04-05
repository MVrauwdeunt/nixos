{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.apps.beszel;
in
{
  options.apps.beszel = {
    enable = mkEnableOption "Beszel hub container stack";

    image = mkOption {
      type = types.str;
      default = "docker.io/henrygd/beszel:latest";
      description = "Container image for the Beszel hub";
    };

    tailscaleImage = mkOption {
      type = types.str;
      default = "docker.io/tailscale/tailscale:stable";
      description = "Container image for the Tailscale sidecar";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/beszel";
      description = "Base data directory for Beszel";
    };

    appPort = mkOption {
      type = types.port;
      default = 8090;
      description = "Internal port used by the Beszel hub";
    };

    appUrl = mkOption {
      type = types.str;
      default = "http://beszel:8090";
      description = "Public URL advertised by the Beszel hub";
    };

    tailscaleStateDir = mkOption {
      type = types.path;
      default = "/var/lib/tailscale-beszel";
      description = "Persistent state directory for the Tailscale sidecar";
    };

    tailscaleHostname = mkOption {
      type = types.str;
      default = "sif-beszel";
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
      description = "Open the Beszel port on the host firewall";
    };

    serveConfigFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to a JSON file for Tailscale Serve configuration";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root - -"
      "d ${cfg.dataDir}/hub 0755 root root - -"
      "d ${cfg.tailscaleStateDir} 0755 root root - -"
    ];

    virtualisation.oci-containers.containers = {
      tailscale-beszel = {
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
            "--hostname=tailscale-beszel"
            "--network=bridge"
            "--userns=host"
          ]
          ++ optionals (!cfg.userspaceNetworking) [
            "--cap-add=NET_ADMIN"
            "--cap-add=NET_RAW"
            "--device=/dev/net/tun"
          ];
      };

      beszel = {
        image = cfg.image;
        autoStart = true;
        dependsOn = [ "tailscale-beszel" ];

        environment = {
          APP_URL = cfg.appUrl;
        };

        volumes = [
          "${cfg.dataDir}/hub:/beszel_data"
        ];

        extraOptions = [
          "--hostname=beszel"
          "--network=container:tailscale-beszel"
          "--userns=host"
        ];
      };
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.appPort ];
    };

    systemd.services.podman-beszel.after = [
      "network-online.target"
      "podman-tailscale-beszel.service"
    ];

    systemd.services.podman-beszel.wants = [ "network-online.target" ];

    systemd.services.podman-beszel.requires = [
      "podman-tailscale-beszel.service"
    ];

    systemd.services.podman-tailscale-beszel.after = [ "network-online.target" ];
    systemd.services.podman-tailscale-beszel.wants = [ "network-online.target" ];
  };
}

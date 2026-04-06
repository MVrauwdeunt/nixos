{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.apps.forgejo;
in
{
  options.apps.forgejo = {
    enable = mkEnableOption "Forgejo container stack";

    image = mkOption {
      type = types.str;
      default = "codeberg.org/forgejo/forgejo:14";
      description = "Container image for Forgejo";
    };

    tailscaleImage = mkOption {
      type = types.str;
      default = "docker.io/tailscale/tailscale:stable";
      description = "Container image for the Tailscale sidecar";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/forgejo";
      description = "Base data directory for Forgejo";
    };

    appPort = mkOption {
      type = types.port;
      default = 3000;
      description = "Internal port used by Forgejo";
    };

    appUrl = mkOption {
      type = types.str;
      default = "https://forgejo.fiordland-gar.ts.net";
      description = "Public URL advertised by Forgejo";
    };

    tailscaleStateDir = mkOption {
      type = types.path;
      default = "/var/lib/tailscale-forgejo";
      description = "Persistent state directory for the Tailscale sidecar";
    };

    tailscaleHostname = mkOption {
      type = types.str;
      default = "forgejo";
      description = "Hostname used by the Tailscale sidecar";
    };

    tailscaleAuthFile = mkOption {
      type = types.path;
      description = "Path to an env file containing Tailscale OAuth credentials";
    };

    tailscaleAdvertiseTags = mkOption {
      type = types.listOf types.str;
      default = [ "tag:containers" ];
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
      description = "Open the Forgejo port on the host firewall";
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
      "d ${cfg.tailscaleStateDir} 0755 root root - -"
    ];

    virtualisation.oci-containers.containers = {
      tailscale-forgejo = {
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
            "--hostname=tailscale-forgejo"
            "--network=bridge"
            "--userns=host"
          ]
          ++ optionals (!cfg.userspaceNetworking) [
            "--cap-add=NET_ADMIN"
            "--cap-add=NET_RAW"
            "--device=/dev/net/tun"
          ];
      };

      forgejo = {
        image = cfg.image;
        autoStart = true;
        dependsOn = [ "tailscale-forgejo" ];

        environment = {
          FORGEJO__server__ROOT_URL = cfg.appUrl;
        };

        volumes = [
          "${cfg.dataDir}:/data"
        ];

        extraOptions = [
          "--hostname=forgejo"
          "--network=container:tailscale-forgejo"
          "--userns=host"
        ];
      };
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.appPort ];
    };

    systemd.services.podman-forgejo.after = [
      "network-online.target"
      "podman-tailscale-forgejo.service"
    ];

    systemd.services.podman-forgejo.wants = [ "network-online.target" ];

    systemd.services.podman-forgejo.requires = [
      "podman-tailscale-forgejo.service"
    ];

    systemd.services.podman-tailscale-forgejo.after = [ "network-online.target" ];
    systemd.services.podman-tailscale-forgejo.wants = [ "network-online.target" ];
  };
}

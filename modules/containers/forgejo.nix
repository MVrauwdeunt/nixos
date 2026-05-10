{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.apps.forgejo;
in
{
  options.apps.forgejo = {
    enable = mkEnableOption "Forgejo container stack";

    tailscale.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Expose this app through Tailscale Serve.";
    };

    image = mkOption {
      type = types.str;
      default = "codeberg.org/forgejo/forgejo:14";
      description = "Container image for Forgejo";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/forgejo";
      description = "Base data directory for Forgejo";
    };

    port = mkOption {
      type = types.port;
      default = 3000;
      description = "Forgejo web UI port.";
    };

    sshPort = mkOption {
      type = types.port;
      default = 2222;
      description = "Host and container SSH port used by Forgejo";
    };

    tailscale.tcpPorts = mkOption {
      type = types.listOf types.port;
      default = [ 2222 ];
      description = "TCP ports to expose through Tailscale Serve.";
    };

    appUrl = mkOption {
      type = types.str;
      default = "https://forgejo.fiordland-gar.ts.net";
      description = "Public URL advertised by Forgejo";
    };

    sshDomain = mkOption {
      type = types.str;
      default = "forgejo.fiordland-gar.ts.net";
      description = "Public SSH domain advertised by Forgejo";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the Forgejo ports on the host firewall";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root - -"
    ];

    virtualisation.oci-containers.containers.forgejo = {
      image = cfg.image;
      autoStart = true;

      environment = {
        FORGEJO__server__ROOT_URL = cfg.appUrl;
        FORGEJO__server__START_SSH_SERVER = "true";
        FORGEJO__server__SSH_DOMAIN = cfg.sshDomain;
        FORGEJO__server__SSH_PORT = toString cfg.sshPort;
        FORGEJO__server__SSH_LISTEN_PORT = toString cfg.sshPort;
      };

      volumes = [
        "${cfg.dataDir}:/data"
      ];

      ports = [
        "127.0.0.1:${toString cfg.port}:${toString cfg.port}"
        "127.0.0.1:${toString cfg.sshPort}:${toString cfg.sshPort}"
      ];

      extraOptions = [
        "--hostname=forgejo"
        "--userns=host"
      ];
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port cfg.sshPort ];
    };

    systemd.services.podman-forgejo.after = [ "network-online.target" ];
    systemd.services.podman-forgejo.wants = [ "network-online.target" ];
  };
}
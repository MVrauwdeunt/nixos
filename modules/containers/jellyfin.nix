
{ config, lib, ... }:

let
  cfg = config.apps.jellyfin;
in
{
  options.apps.jellyfin = {
    enable = lib.mkEnableOption "Jellyfin container";

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Jellyfin through Tailscale Serve.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/jellyfin";
    };

    mediaDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/shares/Media";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8096;
      description = "Jellyfin web UI port.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    enableHardwareAcceleration = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";
    virtualisation.podman.enable = true;

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 1000 1000 -"
    ];

    virtualisation.oci-containers.containers.jellyfin = {
      image = "docker.io/jellyfin/jellyfin:12.3@sha256:2038fe038ab3876a80f6e7b7e0aef6607b032c7dc0c9b3ad3296d0b2eba3bbb5";
      pull = "missing";

      ports = [
        "${toString cfg.port}:8096"
      ];

      volumes = [
        "${cfg.dataDir}:/config"
        "${cfg.mediaDir}:/media:ro"
        "${cfg.mediaDir}/Discover:/media/Discover:rw"
      ];

      environment = {
        TZ = "Europe/Amsterdam";
      };

      extraOptions =
        [
          "--network=bridge"
          "--group-add=303"
          "--health-cmd=none"
        ]
        ++ lib.optionals cfg.enableHardwareAcceleration [
          "--device=/dev/dri/renderD128:/dev/dri/renderD128"
        ];
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}

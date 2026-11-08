
{ config, lib, ... }:

let
  cfg = config.apps.jellyfin;
in
{
  imports = [
    (import ./common.nix {
      name = "jellyfin";
      image = "docker.io/jellyfin/jellyfin:12.3@sha256:2038fe038ab3876a80f6e7b7e0aef6607b032c7dc0c9b3ad3296d0b2eba3bbb5";

      port = 8096;
      bindAddress = "0.0.0.0";
      tailscaleDefault = true;
      usePuidPgid = false;
    })
  ];

  options.apps.jellyfin = {
    mediaDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/shares/Media";
    };

    enableHardwareAcceleration = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.jellyfin = {
      volumes = [
        "${cfg.mediaDir}:/media:ro"
        "${cfg.mediaDir}/Discover:/media/Discover:rw"
      ];

      extraOptions = [
        "--group-add=303"
      ] ++ lib.optionals cfg.enableHardwareAcceleration [
        "--device=/dev/dri/renderD128:/dev/dri/renderD128"
      ];
    };
  };
}

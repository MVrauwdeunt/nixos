
{ config, lib, ... }:

let
  cfg = config.apps.manyfold;

  defaultImage =
    "ghcr.io/manyfold3d/manyfold-solo:0.153.0@sha256:161109b917a158b5efd8478a437e9900db7bdc57235c167aa70d5ad69425fc31";
in
{
  imports = [
    (import ./common.nix {
      name = "manyfold";
      image = defaultImage;

      port = 3214;
      containerPort = 3214;
      bindAddress = "127.0.0.1";

      tailscaleDefault = true;

      # De twee volumes gebruiken expliciet :rw.
      mountConfig = false;

      directoryMode = "0750";
      directoryOwner = "1000";
      directoryGroup = "1000";

      # TZ, PUID en PGID komen uit common.nix.
      useTimezone = true;
      usePuidPgid = true;

      # Geen extra Podman-netwerk- of healthcheckopties.
      bridgeNetwork = false;
      disableHealthcheck = false;

      extraOptions = [
        "--security-opt=no-new-privileges:true"
        "--cap-drop=ALL"
        "--cap-add=CHOWN"
        "--cap-add=DAC_OVERRIDE"
        "--cap-add=SETUID"
        "--cap-add=SETGID"
      ];
    })
  ];

  options.apps.manyfold = {
    image = lib.mkOption {
      type = lib.types.str;
      default = defaultImage;
      description = "Manyfold container image.";
    };

    libraryDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/Volume2/3d-models";
      description = "Directory containing 3D model files.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."saga/manyfold/secret_key_base" = {};

    sops.templates."manyfold-env" = {
      content = ''
        SECRET_KEY_BASE=${config.sops.placeholder."saga/manyfold/secret_key_base"}
      '';
    };

    virtualisation.oci-containers.containers.manyfold = {
      image = lib.mkForce cfg.image;

      volumes = [
        "${cfg.dataDir}:/config:rw"
        "${cfg.libraryDir}:/models:rw"
      ];

      environmentFiles = [
        config.sops.templates."manyfold-env".path
      ];
    };

    systemd.services.podman-manyfold = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
    };
  };
}

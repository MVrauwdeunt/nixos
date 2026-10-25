
{ config, lib, ... }:

let
  cfg = config.apps.manyfold;
in
{
  options.apps.manyfold = {
    enable = lib.mkEnableOption "Manyfold 3D model manager";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/manyfold3d/manyfold-solo:0.153.0@sha256:161109b917a158b5efd8478a437e9900db7bdc57235c167aa70d5ad69425fc31";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/manyfold";
    };

    libraryDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/Volume2/3d-models";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3214;
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";

    sops.secrets."saga/manyfold/secret_key_base" = {};

    sops.templates."manyfold-env" = {
      content = ''
        SECRET_KEY_BASE=${config.sops.placeholder."saga/manyfold/secret_key_base"}
      '';
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 1000 1000 -"
    ];

    virtualisation.oci-containers.containers.manyfold = {
      image = cfg.image;
      pull = "missing";
      autoStart = true;

      ports = [
        "127.0.0.1:${toString cfg.port}:3214"
      ];

      volumes = [
        "${cfg.dataDir}:/config:rw"
        "${cfg.libraryDir}:/models:rw"
      ];

      environment = {
        PUID = "1000";
        PGID = "1000";
        TZ = "Europe/Amsterdam";
      };

      environmentFiles = [
        config.sops.templates."manyfold-env".path
      ];

      extraOptions = [
        "--security-opt=no-new-privileges:true"
        "--cap-drop=ALL"
        "--cap-add=CHOWN"
        "--cap-add=DAC_OVERRIDE"
        "--cap-add=SETUID"
        "--cap-add=SETGID"
      ];
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };

    systemd.services.podman-manyfold = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
    };
  };
}

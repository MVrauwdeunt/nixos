{ config, lib, ... }:

let
  cfg = config.apps.manyfold;
in
{
  options.apps.manyfold = {
    enable = lib.mkEnableOption "Manyfold 3D model manager";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/manyfold3d/manyfold-solo:latest";
      description = "Manyfold container image";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/manyfold";
      description = "Persistent Manyfold configuration and database";
    };

    libraryDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/Volume2/3d-models";
      description = "Host directory containing the 3D model library";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3214;
    };

    puid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
    };

    pgid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Manyfold through Tailscale Serve";
    };

    sopsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "SOPS file containing manyfold/secret_key_base";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.sopsFile != null;
        message = "apps.manyfold.sopsFile must be set";
      }
    ];

    virtualisation.oci-containers.backend = "podman";

    sops.secrets."manyfold/secret_key_base" = {
      sopsFile = cfg.sopsFile;
    };

    sops.templates."manyfold-env" = {
      content = ''
        SECRET_KEY_BASE=${config.sops.placeholder."manyfold/secret_key_base"}
      '';
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${toString cfg.puid} ${toString cfg.pgid} -"
    ];

    virtualisation.oci-containers.containers.manyfold = {
      image = cfg.image;
      autoStart = true;

      ports = [
        "127.0.0.1:${toString cfg.port}:3214"
      ];

      volumes = [
        "${cfg.dataDir}:/config:rw"
        "${cfg.libraryDir}:/models:rw"
      ];

      environment = {
        PUID = toString cfg.puid;
        PGID = toString cfg.pgid;
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

{ config, lib, ... }:

let
  cfg = config.apps.lidify;
in
{
  options.apps.lidify = {
    enable = lib.mkEnableOption "Lidify container";

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Lidify through Tailscale Serve.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/thewicklowwolf/lidify:0.2.11@sha256:3e99fa32bd5f4462e61d07ac949ca3443931f4a62a3cfcf443ec804814a2cd76";
      description = "Lidify container image.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/lidify";
    };

    secretName = lib.mkOption {
      type = lib.types.str;
      default = "mimir/lidify/env";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5000;
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.lidify = {
      image = cfg.image;
      pull = "missing";

      networks = [ "arr-internal" ];

      ports = [
        "127.0.0.1:${toString cfg.port}:5000"
      ];

      volumes = [
        "${cfg.dataDir}:/lidify/config"
        "/etc/localtime:/etc/localtime:ro"
      ];

      environmentFiles = [
        config.sops.secrets.${cfg.secretName}.path
      ];

      environment = {
        TZ = "Europe/Amsterdam";
        PUID = "1000";
        PGID = "1000";
        mode = "LastFM";
        lidarr_address = "http://lidarr:8686";
        root_folder_path = "/music";
        search_for_missing_albums = "False";
        dry_run_adding_to_lidarr = "False";
      };

      extraOptions = [
        "--health-cmd=none"
      ];
    };

    systemd.services.podman-lidify = {
      requires = [
        "podman-network-arr-internal.service"
      ];

      after = [
        "podman-network-arr-internal.service"
        "podman-lidarr.service"
      ];
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 1000 1000 -"
    ];

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}

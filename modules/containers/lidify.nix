{ config, lib, ... }:

{
  imports = [
    (import ./common.nix {
      name = "lidify";
      image = "docker.io/thewicklowwolf/lidify:0.2.11@sha256:3e99fa32bd5f4462e61d07ac949ca3443931f4a62a3cfcf443ec804814a2cd76";
      port = 5000;
      tailscaleDefault = true;

      configMount = "/lidify/config";
      networks = [ "arr-internal" ];
      extraVolumes = [ "/etc/localtime:/etc/localtime:ro" ];
      environment = {
        mode = "LastFM";
        lidarr_address = "http://lidarr:8686";
        root_folder_path = "/music";
        search_for_missing_albums = "False";
        dry_run_adding_to_lidarr = "False";
      };
    })
  ];

  options.apps.lidify.secretName = lib.mkOption {
    type = lib.types.str;
    default = "mimir/lidify/env";
  };

  config = lib.mkIf config.apps.lidify.enable {
    virtualisation.oci-containers.containers.lidify.environmentFiles = [
      config.sops.secrets.${config.apps.lidify.secretName}.path
    ];

    systemd.services.podman-lidify.after = [ "podman-lidarr.service" ];
  };
}

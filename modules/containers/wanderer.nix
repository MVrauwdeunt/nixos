
{ config, lib, pkgs, ... }:

let
  cfg = config.apps.wanderer;

  envFile = config.sops.templates."wanderer.env".path;
in
{
  imports = [
    (import ./common.nix {
      name = "wanderer";

      image = "docker.io/flomp/wanderer-web:v0.21.1@sha256:e57900a59a746d6f1cab3f191a54a5760922ecccad93f13d61d0fb3188335da4";

      port = 3001;
      containerPort = 3000;
      bindAddress = "127.0.0.1";
      tailscaleDefault = true;

      mountConfig = false;
      createDataDir = false;

      useTimezone = false;
      usePuidPgid = false;
      bridgeNetwork = false;
      disableHealthcheck = false;

      extraVolumes = [
        "/var/lib/wanderer/uploads:/app/uploads"
      ];

      environment = {
        MEILI_URL = "http://search:7700";
        ORIGIN = "https://wanderer.fiordland-gar.ts.net";
        BODY_SIZE_LIMIT = "Infinity";
        PUBLIC_POCKETBASE_URL = "http://db:8090";
        PUBLIC_DISABLE_SIGNUP = "false";
        UPLOAD_FOLDER = "/app/uploads";
        VALHALLA_URL = "https://valhalla1.openstreetmap.de";
        NOMINATIM_URL = "https://nominatim.openstreetmap.org";
        OVERPASS_API_URL = "https://overpass-api.de";
      };

      extraOptions = [
        "--network=wanderer"
      ];
    })

    (import ./common.nix {
      name = "wanderer-db";

      image = "docker.io/flomp/wanderer-db:v0.21.1@sha256:1575a18a025af284185612d165ec80bb4a6e0c7727c157c6a6edbe917853d10e";

      port = 8090;
      bindAddress = "127.0.0.1";

      dataDir = "/var/lib/wanderer/pb_data";
      configMount = "/pb_data";
      createDataDir = false;

      useTimezone = false;
      usePuidPgid = false;
      bridgeNetwork = false;
      disableHealthcheck = false;

      extraVolumes = [
        "/var/lib/wanderer/plugins:/data/plugins"
      ];

      environment = {
        MEILI_URL = "http://search:7700";
        ORIGIN = "https://wanderer.fiordland-gar.ts.net";
      };

      extraOptions = [
        "--network=wanderer"
        "--network-alias=db"
      ];
    })

    (import ./common.nix {
      name = "wanderer-search";

      image = "docker.io/getmeili/meilisearch:v1.36.0@sha256:203a0854738be101bfdada825ac3cbf95e5681bc849757b6bc199e4cfae98faa";

      port = 7700;
      publishedPorts = [ ];

      dataDir = "/var/lib/wanderer/meili-v1.36";
      configMount = "/meili_data";
      createDataDir = false;

      useTimezone = false;
      usePuidPgid = false;
      bridgeNetwork = false;
      disableHealthcheck = false;

      environment = {
        MEILI_URL = "http://127.0.0.1:7700";
        MEILI_NO_ANALYTICS = "true";
      };

      extraOptions = [
        "--network=wanderer"
        "--network-alias=search"
      ];
    })
  ];

  config = lib.mkMerge [
    {
      apps.wanderer-db.enable = cfg.enable;
      apps.wanderer-search.enable = cfg.enable;
    }

    (lib.mkIf cfg.enable {
      sops.secrets."saga/wanderer_meili_master_key" = {};
      sops.secrets."saga/wanderer_pocketbase_encryption_key" = {};
      sops.secrets."saga/wanderer_pocketbase_proxy_secret" = {};

      sops.templates."wanderer.env".content = ''
        MEILI_MASTER_KEY=${config.sops.placeholder."saga/wanderer_meili_master_key"}
        POCKETBASE_ENCRYPTION_KEY=${config.sops.placeholder."saga/wanderer_pocketbase_encryption_key"}
        POCKETBASE_PROXY_SECRET=${config.sops.placeholder."saga/wanderer_pocketbase_proxy_secret"}
      '';

      systemd.tmpfiles.rules = [
        "d /var/lib/wanderer 0755 root root -"
        "d /var/lib/wanderer/pb_data 0755 root root -"
        "d /var/lib/wanderer/uploads 0755 root root -"
      ];

      systemd.services.wanderer-network = {
        description = "Create Wanderer Podman network";

        wantedBy = [ "multi-user.target" ];

        before = [
          "podman-wanderer-search.service"
          "podman-wanderer-db.service"
          "podman-wanderer.service"
        ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        script = ''
          ${pkgs.podman}/bin/podman network exists wanderer \
            || ${pkgs.podman}/bin/podman network create wanderer
        '';
      };

      systemd.services.podman-wanderer-search = {
        requires = [ "wanderer-network.service" ];
        after = [ "wanderer-network.service" ];
      };

      systemd.services.podman-wanderer-db = {
        requires = [ "wanderer-network.service" ];

        after = [
          "wanderer-network.service"
          "podman-wanderer-search.service"
        ];
      };

      systemd.services.podman-wanderer = {
        requires = [ "wanderer-network.service" ];

        after = [
          "wanderer-network.service"
          "podman-wanderer-search.service"
          "podman-wanderer-db.service"
        ];
      };

      virtualisation.oci-containers.containers = {
        wanderer-search.environmentFiles = [
          envFile
        ];

        wanderer-db = {
          dependsOn = [ "wanderer-search" ];

          environmentFiles = [
            envFile
          ];
        };

        wanderer = {
          dependsOn = [
            "wanderer-search"
            "wanderer-db"
          ];

          environmentFiles = [
            envFile
          ];
        };
      };
    })
  ];
}

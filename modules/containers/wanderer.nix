{ config, lib, pkgs, ... }:

let
  cfg = config.apps.wanderer;
in
{
  options.apps.wanderer = {
    enable = lib.mkEnableOption "Wanderer";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3001;
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
    sops.secrets."saga/wanderer_meili_master_key" = {};
    sops.secrets."saga/wanderer_pocketbase_encryption_key" = {};

    sops.templates."wanderer.env".content = ''
      MEILI_MASTER_KEY=${config.sops.placeholder."saga/wanderer_meili_master_key"}
      POCKETBASE_ENCRYPTION_KEY=${config.sops.placeholder."saga/wanderer_pocketbase_encryption_key"}
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
      wanderer-search = {
        image = "docker.io/getmeili/meilisearch:v1.11.3";
        pull = "always";

        volumes = [
          "/var/lib/wanderer/data.ms:/meili_data/data.ms"
        ];

        environment = {
          MEILI_URL = "http://127.0.0.1:7700";
          MEILI_NO_ANALYTICS = "true";
        };

        environmentFiles = [
          config.sops.templates."wanderer.env".path
        ];

        extraOptions = [
          "--network=wanderer"
          "--network-alias=search"
        ];
      };

      wanderer-db = {
        image = "docker.io/flomp/wanderer-db:latest";
        pull = "always";

        dependsOn = [
          "wanderer-search"
        ];

        ports = [
          "127.0.0.1:8090:8090"
        ];

        volumes = [
          "/var/lib/wanderer/pb_data:/pb_data"
          "/var/lib/wanderer/plugins:/data/plugins"
        ];

        environment = {
          MEILI_URL = "http://search:7700";
          ORIGIN = "https://wanderer.fiordland-gar.ts.net";
        };

        environmentFiles = [
          config.sops.templates."wanderer.env".path
        ];

        extraOptions = [
          "--network=wanderer"
          "--network-alias=db"
        ];
      };

      wanderer = {
        image = "docker.io/flomp/wanderer-web:latest";
        pull = "always";

        dependsOn = [
          "wanderer-search"
          "wanderer-db"
        ];

        ports = [
          "127.0.0.1:${toString cfg.port}:3000"
        ];

        volumes = [
          "/var/lib/wanderer/uploads:/app/uploads"
        ];

        environment = {
          MEILI_URL = "http://search:7700";
          ORIGIN = "https://wanderer.fiordland-gar.ts.net";
          BODY_SIZE_LIMIT = "Infinity";
          PUBLIC_POCKETBASE_URL = "http://db:8090";
          PUBLIC_DISABLE_SIGNUP = "false";
          UPLOAD_FOLDER = "/app/uploads";
          PUBLIC_VALHALLA_URL = "https://valhalla1.openstreetmap.de";
          PUBLIC_NOMINATIM_URL = "https://nominatim.openstreetmap.org";
        };

        environmentFiles = [
          config.sops.templates."wanderer.env".path
        ];

        extraOptions = [
          "--network=wanderer"
        ];
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}

{ config, lib, pkgs, ... }:

let
  cfg = config.apps.karakeep;
in
{
  options.apps.karakeep = {
    enable = lib.mkEnableOption "Karakeep";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3003;
      description = "Local Karakeep web port.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Karakeep through Tailscale Services.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."saga/karakeep_nextauth_secret" = {};
    sops.secrets."saga/karakeep_meili_master_key" = {};
    sops.secrets."saga/karakeep_openai_api_key" = {};

    sops.templates."karakeep-app.env".content = ''
      NEXTAUTH_SECRET=${config.sops.placeholder."saga/karakeep_nextauth_secret"}
      MEILI_MASTER_KEY=${config.sops.placeholder."saga/karakeep_meili_master_key"}
      OPENAI_API_KEY=${config.sops.placeholder."saga/karakeep_openai_api_key"}
    '';

    sops.templates."karakeep-meilisearch.env".content = ''
      MEILI_MASTER_KEY=${config.sops.placeholder."saga/karakeep_meili_master_key"}
    '';

    systemd.tmpfiles.rules = [
      "d /var/lib/karakeep 0755 root root -"
      "d /var/lib/karakeep/data 0755 root root -"
      "d /var/lib/karakeep/meilisearch 0755 root root -"
    ];

    systemd.services.podman-network-karakeep = {
      description = "Create Karakeep Podman network";
      wantedBy = [ "multi-user.target" ];

      before = [
        "podman-karakeep-app.service"
        "podman-karakeep-chrome.service"
        "podman-karakeep-meilisearch.service"
      ];

      serviceConfig.Type = "oneshot";

      script = ''
        ${pkgs.podman}/bin/podman network exists karakeep \
          || ${pkgs.podman}/bin/podman network create karakeep
      '';
    };

    systemd.services.podman-karakeep-app = {
      requires = [ "podman-network-karakeep.service" ];
      after = [ "podman-network-karakeep.service" ];
    };

    systemd.services.podman-karakeep-chrome = {
      requires = [ "podman-network-karakeep.service" ];
      after = [ "podman-network-karakeep.service" ];
    };

    systemd.services.podman-karakeep-meilisearch = {
      requires = [ "podman-network-karakeep.service" ];
      after = [ "podman-network-karakeep.service" ];
    };

    virtualisation.oci-containers.containers = {
      karakeep-app = {
        image = "ghcr.io/karakeep-app/karakeep:release";
        pull = "always";

        dependsOn = [
          "karakeep-chrome"
          "karakeep-meilisearch"
        ];

        ports = [
          "127.0.0.1:${toString cfg.port}:3000"
        ];

        environment = {
          MEILI_ADDR = "http://karakeep-meilisearch:7700";
          BROWSER_WEB_URL = "http://karakeep-chrome:9222";

          NEXTAUTH_URL = "https://karakeep.fiordland-gar.ts.net";

          DATA_DIR = "/data";

          CRAWLER_STORE_SCREENSHOT = "true";
          CRAWLER_FULL_PAGE_SCREENSHOT = "true";
          CRAWLER_ENABLE_ADBLOCKER = "true";
        };

        environmentFiles = [
          config.sops.templates."karakeep-app.env".path
        ];

        volumes = [
          "/var/lib/karakeep/data:/data"
        ];

        extraOptions = [
          "--network=karakeep"
        ];
      };

      karakeep-chrome = {
        image = "ghcr.io/karakeep-app/karakeep-chrome:release";
        pull = "always";

        cmd = [
          "--disable-gpu"
          "--disable-dev-shm-usage"
          "--hide-scrollbars"
          "--disable-blink-features=AutomationControlled"
          "--window-size=1440,900"
        ];

        extraOptions = [
          "--network=karakeep"
          "--init"
        ];
      };

      karakeep-meilisearch = {
        image = "docker.io/getmeili/meilisearch:v1.13.3";
        pull = "always";

        environment = {
          MEILI_NO_ANALYTICS = "true";
        };

        environmentFiles = [
          config.sops.templates."karakeep-meilisearch.env".path
        ];

        volumes = [
          "/var/lib/karakeep/meilisearch:/meili_data"
        ];

        extraOptions = [
          "--network=karakeep"
        ];
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
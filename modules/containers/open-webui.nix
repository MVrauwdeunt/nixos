
{ config, lib, ... }:

let
  cfg = config.apps.open-webui;
in
{
  options.apps.open-webui = {
    enable = lib.mkEnableOption "Open WebUI";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Local Open WebUI web port.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the Open WebUI port in the firewall.";
    };

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Open WebUI through Tailscale Services.";
    };

    tailscale.serviceName = lib.mkOption {
      type = lib.types.str;
      default = "openwebui";
      description = "Tailscale Service name.";
    };

    oidc.enable =
      lib.mkEnableOption "Authelia OpenID Connect login";

    oidc.localLogin = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Keep local login available during migration.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."vili/open-webui/env" = {
      sopsFile = ../../secrets.yaml;
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/open-webui 0755 root root -"
    ];

    virtualisation.oci-containers.containers.open-webui = {
      image = "ghcr.io/open-webui/open-webui:v0.12.3@sha256:a537bbe1e6b428820f52ed4a029d7fff97062e24d5cf32c365fba36fd0542def";
      pull = "missing";

      ports = [
        "127.0.0.1:${toString cfg.port}:8080"
      ];

      extraOptions = [
        "--network=ai-backend"
      ];

      volumes = [
        "/var/lib/open-webui:/app/backend/data"
      ];

      environment = {
        ENABLE_OPENAI_API = "True";
        OPENAI_API_BASE_URL = "http://litellm:4000/v1";
        ENABLE_OLLAMA_API = "False";

        WEBUI_URL = "https://ai.gladsheimr.nl";
      } // lib.optionalAttrs cfg.oidc.enable {
        ENABLE_OAUTH_SIGNUP = "True";

        OAUTH_PROVIDER_NAME = "Authelia";

        OPENID_PROVIDER_URL =
          "https://auth.gladsheimr.nl/.well-known/openid-configuration";

        OAUTH_CLIENT_ID = "open-webui";

        OAUTH_SCOPES = "openid email profile groups";

        OAUTH_CODE_CHALLENGE_METHOD = "S256";

        ENABLE_LOGIN_FORM =
          if cfg.oidc.localLogin then "True" else "False";
      };

      environmentFiles = [
        config.sops.secrets."vili/open-webui/env".path
      ];
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}

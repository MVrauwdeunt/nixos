
{ config, lib, ... }:

let
  cfg = config.apps.open-webui;
in
{
  imports = [
    (import ./common.nix {
      name = "open-webui";

      image =
        "ghcr.io/open-webui/open-webui:v0.12.3@sha256:a537bbe1e6b428820f52ed4a029d7fff97062e24d5cf32c365fba36fd0542def";

      port = 3000;
      containerPort = 8080;

      dataDir = "/var/lib/open-webui";
      configMount = "/app/backend/data";

      directoryOwner = "root";
      directoryGroup = "root";

      tailscaleDefault = true;

      useTimezone = false;
      usePuidPgid = false;
      bridgeNetwork = false;
      disableHealthcheck = false;

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

      extraOptions = [ "--network=ai-backend" ];
    })
  ];

  options.apps.open-webui = {
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

    virtualisation.oci-containers.containers.open-webui.environmentFiles = [
      config.sops.secrets."vili/open-webui/env".path
    ];
  };
}

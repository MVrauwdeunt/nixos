
{ config, lib, ... }:

let
  cfg = config.apps.actual-budget;

  oidcSecret = "saga/actual_budget_oidc_client_secret";
  oidcSecretPath = config.sops.secrets.${oidcSecret}.path;
in
{
  imports = [
    (import ./common.nix {
      name = "actual-budget";

      image = "ghcr.io/actualbudget/actual-server:26.10.0@sha256:24645e971da6bb1a1f953d6859e307a0b29be1e8b4130a35b3220c209b5b860c";

      port = 5006;
      bindAddress = "127.0.0.1";
      configMount = "/data";

      tailscaleDefault = true;

      directoryMode = "0750";

      # De oorspronkelijke container gebruikte alleen TZ.
      usePuidPgid = false;

      # Behoud het bestaande Podman-gedrag.
      bridgeNetwork = false;
      disableHealthcheck = false;

      environment = {
        ACTUAL_UPLOAD_FILE_SIZE_LIMIT_MB = "100";
        ACTUAL_UPLOAD_FILE_SYNC_SIZE_LIMIT_MB = "100";
        ACTUAL_UPLOAD_SYNC_ENCRYPTED_FILE_SYNC_SIZE_LIMIT_MB = "100";
      };
    })
  ];

  options.apps.actual-budget = {
    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/actualbudget/actual-server:26.10.0@sha256:24645e971da6bb1a1f953d6859e307a0b29be1e8b4130a35b3220c209b5b860c";
      description = "Actual Budget container image.";
    };

    tailscale.serviceName = lib.mkOption {
      type = lib.types.str;
      default = "budget";
      description = "Tailscale service name.";
    };

    oidc = {
      enable = lib.mkEnableOption "Authelia OpenID Connect";

      discoveryURL = lib.mkOption {
        type = lib.types.str;
        default =
          "https://auth.gladsheimr.nl/.well-known/openid-configuration";
        description = "Authelia OIDC discovery URL.";
      };

      clientId = lib.mkOption {
        type = lib.types.str;
        default = "actual-budget";
        description = "OIDC client ID.";
      };

      serverURL = lib.mkOption {
        type = lib.types.str;
        default = "https://budget.fiordland-gar.ts.net";
        description = "Actual Budget URL.";
      };

      enforce = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Require OpenID authentication.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets = lib.mkIf cfg.oidc.enable {
      ${oidcSecret} = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    virtualisation.oci-containers.containers.actual-budget = {
      image = lib.mkForce cfg.image;

      autoStart = true;

      volumes = lib.mkAfter (
        lib.optionals cfg.oidc.enable [
          "${oidcSecretPath}:/run/secrets/actual-oidc-client-secret:ro"
        ]
      );

      environment = lib.optionalAttrs cfg.oidc.enable {
        ACTUAL_OPENID_DISCOVERY_URL = cfg.oidc.discoveryURL;
        ACTUAL_OPENID_CLIENT_ID = cfg.oidc.clientId;
        ACTUAL_OPENID_SERVER_HOSTNAME = cfg.oidc.serverURL;
        ACTUAL_OPENID_AUTH_METHOD = "oauth2";

        ACTUAL_OPENID_CLIENT_SECRET_FILE =
          "/run/secrets/actual-oidc-client-secret";

        ACTUAL_TOKEN_EXPIRATION = "openid-provider";
        ACTUAL_USER_CREATION_MODE = "manual";

        ACTUAL_OPENID_ENFORCE =
          if cfg.oidc.enforce then "true" else "false";
      };
    };
  };
}

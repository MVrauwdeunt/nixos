
{ config, lib, ... }:

let
  cfg = config.apps.actual-budget;

  oidcSecret = "saga/actual_budget_oidc_client_secret";
  oidcSecretPath = config.sops.secrets.${oidcSecret}.path;
in
{
  options.apps.actual-budget = {
    enable = lib.mkEnableOption "Actual Budget";

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/actualbudget/actual-server:latest";
      description = "Actual Budget container image.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/actual-budget";
      description = "Persistent Actual Budget data directory.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5006;
      description = "Local HTTP port for Actual Budget.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open Actual Budget port in host firewall.";
    };

    tailscale = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Expose Actual Budget through Tailscale Services.";
      };

      serviceName = lib.mkOption {
        type = lib.types.str;
        default = "budget";
        description = "Tailscale service name.";
      };
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

    # Original (unhashed) OIDC client secret from SOPS
    sops.secrets = lib.mkIf cfg.oidc.enable {
      ${oidcSecret} = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    # Persistent data storage
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 1000 1000 -"
    ];

    # Actual Budget Podman container
    virtualisation.oci-containers.containers.actual-budget = {
      image = cfg.image;
      autoStart = true;
      pull = "always";

      ports = [
        "127.0.0.1:${toString cfg.port}:5006"
      ];

      volumes =
        [
          "${cfg.dataDir}:/data"
        ]
        ++ lib.optionals cfg.oidc.enable [
          "${oidcSecretPath}:/run/secrets/actual-oidc-client-secret:ro"
        ];

      environment = {
        TZ = "Europe/Amsterdam";
      } // lib.optionalAttrs cfg.oidc.enable {
        ACTUAL_OPENID_DISCOVERY_URL = cfg.oidc.discoveryURL;
        ACTUAL_OPENID_CLIENT_ID = cfg.oidc.clientId;
        ACTUAL_OPENID_SERVER_HOSTNAME = cfg.oidc.serverURL;
        ACTUAL_OPENID_AUTH_METHOD = "oauth2";

        # Client secret is read from file, not environment
        ACTUAL_OPENID_CLIENT_SECRET_FILE =
          "/run/secrets/actual-oidc-client-secret";

        ACTUAL_TOKEN_EXPIRATION = "openid-provider";
        ACTUAL_USER_CREATION_MODE = "manual";

        # Keep password login until OIDC is verified
        ACTUAL_OPENID_ENFORCE =
          if cfg.oidc.enforce then "true" else "false";
      };
    };

    networking.firewall.allowedTCPPorts =
      lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}

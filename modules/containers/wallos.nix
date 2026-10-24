
{ config, lib, ... }:

let
  cfg = config.apps.wallos;

  oidcSecretName = "saga/wallos_oidc_client_secret";

in
{
  options.apps.wallos = {
    enable = lib.mkEnableOption
      "Wallos subscription tracker";

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/bellamy/wallos@sha256:b12fc3f6456fa4879346d27f13c96011a1dce8d5285ef31fcec9323f2bac9854";
      description = "Wallos container image.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/wallos";
      description = "Persistent Wallos data directory.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8282;
      description = "Local HTTP port for Wallos.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the Wallos port in the host firewall.";
    };

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Wallos through Tailscale Services.";
    };

    oidc = {
      enable = lib.mkEnableOption
        "Authelia OIDC authentication";

      issuer = lib.mkOption {
        type = lib.types.str;
        default = "https://auth.gladsheimr.nl";
      };

      clientId = lib.mkOption {
        type = lib.types.str;
        default = "wallos";
      };

      redirectURL = lib.mkOption {
        type = lib.types.str;
        default =
          "https://wallos.fiordland-gar.ts.net/index.php";
      };

      autoCreateUser = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };

      disablePasswordLogin = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };
  };

  config = lib.mkIf cfg.enable {

    # PHP-FPM draait in Wallos als www-data (GID 82).
    users.groups = lib.mkIf cfg.oidc.enable {
      wallos-oidc = {
        gid = 82;
      };
    };

    # OIDC-secret via SOPS.
    sops.secrets = lib.mkIf cfg.oidc.enable {
      "${oidcSecretName}" = {
        sopsFile = ../../secrets.yaml;
        owner = "root";
        group = "wallos-oidc";
        mode = "0440";
      };
    };

    # Persistente directories.
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
      "d ${cfg.dataDir}/db 0755 root root -"
      "d ${cfg.dataDir}/logos 0755 82 82 -"
    ];

    # Podman-container.
    virtualisation.oci-containers.containers.wallos = {
      image = cfg.image;
      pull = "missing";
      autoStart = true;

      ports = [
        "127.0.0.1:${toString cfg.port}:80"
      ];

      volumes =
        [
          "${cfg.dataDir}/db:/var/www/html/db"
          "${cfg.dataDir}/logos:/var/www/html/images/uploads/logos"
        ]
        ++ lib.optionals cfg.oidc.enable [
          "${config.sops.secrets.${oidcSecretName}.path}:/run/secrets/wallos-oidc-secret:ro"
        ];

      environment =
        {
          TZ = "Europe/Amsterdam";
        }
        // lib.optionalAttrs cfg.oidc.enable {
          OIDC_ENABLED = "true";
          OIDC_PROVIDER_NAME = "Authelia";

          OIDC_CLIENT_ID = cfg.oidc.clientId;

          OIDC_CLIENT_SECRET_FILE =
            "/run/secrets/wallos-oidc-secret";

          OIDC_ISSUER = cfg.oidc.issuer;

          OIDC_REDIRECT_URL =
            cfg.oidc.redirectURL;

          OIDC_SCOPES = "openid email profile";

          OIDC_AUTO_CREATE_USER =
            lib.boolToString cfg.oidc.autoCreateUser;

          OIDC_DISABLE_PASSWORD_LOGIN =
            lib.boolToString cfg.oidc.disablePasswordLogin;
        };

      # DNS via Saga's systemd-resolved.
      # Publieke DNS en Tailscale MagicDNS.
      extraOptions = [
        "--dns=10.88.0.1"
      ];
    };

    # Firewall.
    networking.firewall.allowedTCPPorts =
      lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}

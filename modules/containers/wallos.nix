
{ config, lib, ... }:

let
  cfg = config.apps.wallos;

  oidcSecretName = "saga/wallos_oidc_client_secret";

  defaultImage =
    "docker.io/bellamy/wallos:5.10.2@sha256:8873c2328e745c7ca8ff0e0f5508215219ec5c02a3469c0d8049602be2a2bca3";
in
{
  imports = [
    (import ./common.nix {
      name = "wallos";
      image = defaultImage;

      port = 8282;
      containerPort = 80;
      bindAddress = "127.0.0.1";

      dataDir = "/var/lib/wallos";

      tailscaleDefault = true;

      # Wallos uses separate database and logo mounts.
      mountConfig = false;
      createDataDir = false;

      # Wallos manages its own PHP-FPM user.
      useTimezone = true;
      usePuidPgid = false;

      # Preserve existing Podman behaviour.
      bridgeNetwork = false;
      disableHealthcheck = false;

      extraVolumes =
        [
          "${cfg.dataDir}/db:/var/www/html/db"
          "${cfg.dataDir}/logos:/var/www/html/images/uploads/logos"
        ]
        ++ lib.optionals cfg.oidc.enable [
          "${config.sops.secrets.${oidcSecretName}.path}:/run/secrets/wallos-oidc-secret:ro"
        ];

      environment =
        lib.optionalAttrs cfg.oidc.enable {
          OIDC_ENABLED = "true";
          OIDC_PROVIDER_NAME = "Authelia";

          OIDC_CLIENT_ID = cfg.oidc.clientId;

          OIDC_CLIENT_SECRET_FILE =
            "/run/secrets/wallos-oidc-secret";

          OIDC_ISSUER = cfg.oidc.issuer;

          OIDC_REDIRECT_URL = cfg.oidc.redirectURL;

          OIDC_SCOPES = "openid email profile";

          OIDC_AUTO_CREATE_USER =
            lib.boolToString cfg.oidc.autoCreateUser;

          OIDC_DISABLE_PASSWORD_LOGIN =
            lib.boolToString cfg.oidc.disablePasswordLogin;
        };

      extraOptions = [
        "--dns=10.88.0.1"
      ];
    })
  ];

  options.apps.wallos = {
    image = lib.mkOption {
      type = lib.types.str;
      default = defaultImage;
      description = "Wallos container image.";
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
    users.groups = lib.mkIf cfg.oidc.enable {
      wallos-oidc = {
        gid = 82;
      };
    };

    sops.secrets = lib.mkIf cfg.oidc.enable {
      "${oidcSecretName}" = {
        sopsFile = ../../secrets.yaml;
        owner = "root";
        group = "wallos-oidc";
        mode = "0440";
      };
    };

    # Persistent directories.
    #
    # PHP-FPM workers run as www-data (UID/GID 82).
    # SQLite needs write access to the database directory
    # for journal/WAL files, not just to wallos.db.
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
      "d ${cfg.dataDir}/db 0755 82 82 -"
      "d ${cfg.dataDir}/logos 0755 82 82 -"
    ];

    # Keep the image configurable through apps.wallos.image.
    virtualisation.oci-containers.containers.wallos.image =
      lib.mkForce cfg.image;
  };
}

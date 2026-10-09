
{ config, lib, pkgs, ... }:

let
  cfg = config.apps.authelia;

  secret = name: config.sops.placeholder.${name};

  userPasswordKey = name: user:
    if user.passwordKey != null
    then user.passwordKey
    else "authelia/users/${name}_password";

  usersYaml = lib.concatMapStringsSep "\n"
    (name:
      let
        user = cfg.users.${name};
        passwordKey = userPasswordKey name user;
        groups = lib.concatMapStringsSep ", "
          (group: builtins.toJSON group)
          user.groups;
      in ''
        ${name}:
          displayname: ${builtins.toJSON user.displayName}
          email: ${builtins.toJSON user.email}
          groups: [${groups}]
          password: "${secret passwordKey}"
      '')
    (builtins.attrNames cfg.users);

in
{
  options.apps.authelia = {
    enable = lib.mkEnableOption "Authelia (Podman)";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/authelia/authelia:latest";
      description = "Authelia container image";
    };

    hostPort = lib.mkOption {
      type = lib.types.port;
      default = 9091;
      description = "Authelia listening port";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/authelia";
      description = "Persistent Authelia data directory";
    };

    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/etc/authelia";
      description = "Authelia configuration directory";
    };

    sops.file = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "SOPS secrets file";
    };

    oidc.enable =
      lib.mkEnableOption "Authelia OIDC provider for Open WebUI";

    users = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          displayName = lib.mkOption {
            type = lib.types.str;
          };

          email = lib.mkOption {
            type = lib.types.str;
          };

          groups = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
          };

          passwordKey = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
        };
      });

      default = {};
    };

    cookie = {
      domain = lib.mkOption {
        type = lib.types.str;
        default = "gladsheimr.nl";
      };

      portalURL = lib.mkOption {
        type = lib.types.str;
        default = "https://auth.gladsheimr.nl";
      };

      redirectURL = lib.mkOption {
        type = lib.types.str;
        default = "https://auth.gladsheimr.nl";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "authelia_session";
      };

      sameSite = lib.mkOption {
        type = lib.types.enum [ "lax" "strict" "none" ];
        default = "lax";
      };

      expiration = lib.mkOption {
        type = lib.types.str;
        default = "1h";
      };

      inactivity = lib.mkOption {
        type = lib.types.str;
        default = "5m";
      };
    };
  };

  config = lib.mkIf cfg.enable {

    # SOPS secrets

    sops.secrets = lib.mkMerge [
      {
        "authelia/jwt_secret".sopsFile = cfg.sops.file;
        "authelia/session_secret".sopsFile = cfg.sops.file;
        "authelia/storage_encryption_key".sopsFile = cfg.sops.file;
      }

      (lib.mkIf cfg.oidc.enable {
        "authelia/oidc/hmac_secret".sopsFile =
          cfg.sops.file;

        "authelia/oidc/open_webui_client_secret_hash".sopsFile =
          cfg.sops.file;

        "authelia/oidc/jwks_private_key" = {
          sopsFile = ../../secrets/authelia-oidc-key.pem.enc;
          format = "binary";
          mode = "0400";
        };
      })

      (lib.mapAttrs'
        (name: user: {
          name = userPasswordKey name user;
          value.sopsFile = cfg.sops.file;
        })
        cfg.users)
    ];

    # Users database

    sops.templates.authelia-users = {
      mode = "0400";

      content = ''
        users:
        ${lib.concatMapStringsSep "\n"
          (line: "  ${line}")
          (lib.splitString "\n" usersYaml)}
      '';
    };

    # Authelia configuration

    sops.templates.authelia-config = {
      mode = "0400";

      content = ''
        server:
          address: tcp://0.0.0.0:${toString cfg.hostPort}

        log:
          level: info

        session:
          secret: "${secret "authelia/session_secret"}"
          cookies:
            - name: ${cfg.cookie.name}
              domain: ${cfg.cookie.domain}
              authelia_url: ${cfg.cookie.portalURL}
              same_site: ${cfg.cookie.sameSite}
              expiration: ${cfg.cookie.expiration}
              inactivity: ${cfg.cookie.inactivity}

        storage:
          local:
            path: ${cfg.dataDir}/db.sqlite3
          encryption_key: "${secret "authelia/storage_encryption_key"}"

        notifier:
          filesystem:
            filename: ${cfg.dataDir}/notification.txt

        identity_validation:
          reset_password:
            jwt_secret: "${secret "authelia/jwt_secret"}"

        authentication_backend:
          file:
            path: /config/users_database.yml

        access_control:
          default_policy: one_factor

        ${lib.optionalString cfg.oidc.enable ''
        identity_providers:
          oidc:
            hmac_secret: "${secret "authelia/oidc/hmac_secret"}"
            jwks:
              - key_id: open-webui-signing
                algorithm: RS256
                use: sig
                key: {{ secret "/config/oidc-private-key.pem" | mindent 10 "|" | msquote }}
            clients:
              - client_id: open-webui
                client_name: Open WebUI
                client_secret: "${secret "authelia/oidc/open_webui_client_secret_hash"}"
                public: false
                authorization_policy: one_factor
                require_pkce: true
                pkce_challenge_method: S256
                redirect_uris:
                  - https://ai.gladsheimr.nl/oauth/oidc/callback
                  - https://openwebui.fiordland-gar.ts.net/oauth/oidc/callback
                  - https://openwebui.fiordland-gar.ts.net:443/oauth/oidc/callback
                scopes:
                  - openid
                  - profile
                  - email
                  - groups
                response_types:
                  - code
                grant_types:
                  - authorization_code
                token_endpoint_auth_method: client_secret_basic
        ''}
      '';
    };

    # Host configuration paths

    environment.etc."authelia/config.yml".source =
      config.sops.templates.authelia-config.path;

    environment.etc."authelia/users_database.yml".source =
      config.sops.templates.authelia-users.path;

    # Persistent storage

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root - -"
    ];

    # Podman service

    systemd.services.podman-authelia = {
      description = "Authelia (Podman)";

      wantedBy = [ "multi-user.target" ];

      after = [
        "network-online.target"
      ];

      wants = [
        "network-online.target"
      ];

      serviceConfig = {
        Restart = "always";
        RestartSec = 5;
        TimeoutStopSec = 60;

        ExecStartPre = [
          "-${pkgs.podman}/bin/podman rm -f authelia"
          "${pkgs.coreutils}/bin/mkdir -p ${cfg.dataDir}"
        ];

        ExecStart = lib.concatStringsSep " " (
          [
            "${pkgs.podman}/bin/podman run --rm --name authelia"
            "--pull=always"
            "--network host"

            # Directe SOPS-mounts
            "-v ${config.sops.templates.authelia-config.path}:/config/config.yml:ro"
            "-v ${config.sops.templates.authelia-users.path}:/config/users_database.yml:ro"

            # Persistent storage
            "-v ${cfg.dataDir}:/var/lib/authelia:rw"
          ]

          ++ lib.optionals cfg.oidc.enable [
            "-e X_AUTHELIA_CONFIG_FILTERS=template"
            "-v ${config.sops.secrets."authelia/oidc/jwks_private_key".path}:/config/oidc-private-key.pem:ro"
          ]

          ++ [
            cfg.image
            "authelia"
            "--config /config/config.yml"
          ]
        );

        ExecStop =
          "${pkgs.podman}/bin/podman rm -f authelia";
      };
    };
  };
}

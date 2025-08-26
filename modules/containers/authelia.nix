{ config, lib, pkgs, ... }:

let
  cfg = config.apps.authelia;
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
      description = "Host port to bind Authelia to (localhost)";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/authelia";
      description = "Persistent data dir (SQLite DB, notifications)";
    };

    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/etc/authelia";
      description = "Where rendered config/users YAML are placed";
    };

    sops.file = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to secrets.yaml for sops-nix";
    };

    users = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          displayName = lib.mkOption { type = lib.types.str; description = "Display name"; };
          email       = lib.mkOption { type = lib.types.str; description = "Email"; };
          groups      = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; description = "Groups"; };
          # Optional: eigen sleutel in sops voor het wachtwoord-hash
          passwordKey = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; description = "sops key for password hash"; };
        };
      });
      default = {};
      description = "Local users for Authelia file backend";
    };

    cookie = {
      domain = lib.mkOption { type = lib.types.str; default = "gladsheimr.nl"; };
      portalURL = lib.mkOption { type = lib.types.str; default = "https://auth.gladsheimr.nl"; };
      redirectURL = lib.mkOption { type = lib.types.str; default = "https://auth.gladsheimr.nl"; };
      name = lib.mkOption { type = lib.types.str; default = "authelia_session"; };
      sameSite = lib.mkOption { type = lib.types.enum [ "lax" "strict" "none" ]; default = "lax"; };
      expiration = lib.mkOption { type = lib.types.str; default = "1h"; };
      inactivity = lib.mkOption { type = lib.types.str; default = "5m"; };
    };
  };

  config = lib.mkIf cfg.enable {

    #### sops-nix: secrets + templates ####
    # Vereiste secrets: 3 korte strings + per-user password hash
    sops.secrets = lib.mkMerge [
      (lib.optionalAttrs (cfg.sops.file != null) {
        "authelia/jwt_secret".sopsFile = cfg.sops.file;
        "authelia/session_secret".sopsFile = cfg.sops.file;
        "authelia/storage_encryption_key".sopsFile = cfg.sops.file;
      })
      # gebruikers-hashes
      (lib.mapAttrs'
        (name: u:
          let
            passKey =
              if (u ? passwordKey) && (u.passwordKey != null)
              then u.passwordKey
              else "authelia/users/${name}_password";
          in {
            name = passKey;
            value = lib.optionalAttrs (cfg.sops.file != null) { sopsFile = cfg.sops.file; };
          }
        )
        cfg.users)
    ];

    # Helper om een YAML-veilig arraytje van groepen te maken
    # bv: ["admins","dev"] -> " - admins\n  - dev"
    _module.args.autheliaGroupsToYaml = groups:
      if groups == [] then ""
      else lib.concatMapStrings (g: "      - ${g}\n") groups;

    # Render users YAML
    sops.templates.authelia-users = {
      mode = "0400";
      content = let
        usersYaml =
          lib.concatStringsSep ""
            (lib.mapAttrsToList
              (name: u:
                let
                  passKey =
                    if (u ? passwordKey) && (u.passwordKey != null)
                    then u.passwordKey
                    else "authelia/users/${name}_password";
                  groupsYaml = config._module.args.autheliaGroupsToYaml (u.groups or []);
                in ''
                  ${name}:
                    displayname: "${u.displayName}"
                    email: "${u.email}"
                    ${if (u.groups or []) == [] then "groups: []\n" else "groups:\n" + groupsYaml}
                    password: "{{ .${lib.replaceStrings ["/" ] ["." ] passKey} }}"
                '')
              cfg.users);
      in
      ''
        users:
      ${lib.concatMapStrings (s: "  " + s) (lib.splitString "\n" usersYaml)}
      '';
    };

    # Render Authelia config YAML voor 4.38+/4.39:
    # - alleen server.address (geen host/port)
    # - session.secret op top-level
    # - per cookie default_redirection_url verplicht
    # - jwt_secret onder identity_validation.reset_password.jwt_secret
    sops.templates.authelia-config = {
      mode = "0400";
      content = ''
        server:
          address: tcp://0.0.0.0:${toString cfg.hostPort}

        log:
          level: info

        session:
          secret: "{{ .authelia.session_secret }}"
          cookies:
            - name: ${cfg.cookie.name}
              domain: ${cfg.cookie.domain}
              authelia_url: ${cfg.cookie.portalURL}
              default_redirection_url: ${cfg.cookie.redirectURL}
              same_site: ${cfg.cookie.sameSite}
              expiration: ${cfg.cookie.expiration}
              inactivity: ${cfg.cookie.inactivity}

        storage:
          local:
            path: ${cfg.dataDir}/db.sqlite3
          encryption_key: "{{ .authelia.storage_encryption_key }}"

        notifier:
          filesystem:
            filename: ${cfg.dataDir}/notification.txt

        identity_validation:
          reset_password:
            jwt_secret: "{{ .authelia.jwt_secret }}"

        authentication_backend:
          file:
            path: /config/users_database.yml

        access_control:
          default_policy: one_factor
      '';
    };

    #### /etc bind-mount targets ####
    environment.etc."authelia/config.yml".source =
      config.sops.templates.authelia-config.path;
    environment.etc."authelia/users_database.yml".source =
      config.sops.templates.authelia-users.path;

    #### state dir ####
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root - -"
    ];

    #### Podman service ####
    systemd.services.podman-authelia = {
      description = "Authelia (Podman)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Restart = "always";
        TimeoutStopSec = 60;

        # Clean start/stop
        ExecStartPre = [
          "${pkgs.podman}/bin/podman rm -f authelia || true"
          "${pkgs.coreutils}/bin/mkdir -p ${cfg.dataDir}"
        ];

        ExecStart = lib.concatStringsSep " " [
          "${pkgs.podman}/bin/podman run --rm --name authelia"
          "--pull=always"
          "--network host"
          # Healthcheck is standaard ingebouwd; expose niet nodig op host-net
          "-v ${cfg.configDir}:/config:ro,Z"
          "-v ${cfg.dataDir}:/var/lib/authelia:rw,Z"
          "${cfg.image}"
          "authelia"
          "--config /config/config.yml"
        ];

        ExecStop = "${pkgs.podman}/bin/podman rm -f authelia || true";
      };
    };
  };
}

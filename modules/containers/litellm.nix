# modules/containers/litellm.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.apps.litellm;

  litellmConfig = pkgs.writeText "litellm-config.yaml" ''
    model_list:
      - model_name: fast
        litellm_params:
          model: openai/gpt-5.4-mini
          api_key: os.environ/OPENAI_API_KEY

      - model_name: smart
        litellm_params:
          model: openai/gpt-5.5
          api_key: os.environ/OPENAI_API_KEY

      - model_name: automation
        litellm_params:
          model: openai/gpt-4.1-nano
          api_key: os.environ/OPENAI_API_KEY

    general_settings:
      master_key: os.environ/LITELLM_MASTER_KEY
  '';

in
{
  options.apps.litellm = {
    enable = lib.mkEnableOption "LiteLLM AI Gateway";

    port = lib.mkOption {
      type = lib.types.port;
      default = 4000;
      description = "Local LiteLLM API port.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the LiteLLM port in the firewall.";
    };

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose LiteLLM through Tailscale Services.";
    };

    tailscale.serviceName = lib.mkOption {
      type = lib.types.str;
      default = "litellm";
      description = "Tailscale Service name.";
    };
  };

  config = lib.mkIf cfg.enable {

    # ------------------------------------------------------------
    # PostgreSQL 17
    # ------------------------------------------------------------

    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_17;

      # Alleen lokale Unix-sockets.
      enableTCPIP = false;

      ensureDatabases = [
        "litellm"
      ];

      ensureUsers = [
        {
          name = "litellm";
          ensureDBOwnership = true;
        }
      ];

      authentication = lib.mkBefore ''
        local litellm litellm scram-sha-256
      '';

      settings.password_encryption = "scram-sha-256";
    };

    # ------------------------------------------------------------
    # PostgreSQL backups
    # ------------------------------------------------------------

    services.postgresqlBackup = {
      enable = true;
      databases = [ "litellm" ];
      startAt = "*-*-* 03:00:00";
    };

    # ------------------------------------------------------------
    # SOPS secrets
    # ------------------------------------------------------------

    sops.secrets."vili/litellm/env" = {
      sopsFile = ../../secrets.yaml;
    };

    sops.secrets."vili/litellm/db-password" = {
      sopsFile = ../../secrets.yaml;
      owner = "postgres";
      group = "postgres";
      mode = "0400";
    };

    # ------------------------------------------------------------
    # PostgreSQL database password
    # ------------------------------------------------------------

    systemd.services.litellm-db-password = {
      description = "Configure LiteLLM PostgreSQL credentials";

      # Wacht totdat NixOS de database en rol heeft aangemaakt.
      requires = [
        "postgresql-setup.service"
      ];

      after = [
        "postgresql-setup.service"
      ];

      before = [
        "podman-litellm.service"
      ];

      path = [
        pkgs.postgresql_17
      ];

      serviceConfig = {
        Type = "oneshot";
        User = "postgres";
        Group = "postgres";
        RemainAfterExit = true;

        LoadCredential = [
          "db-password:${config.sops.secrets."vili/litellm/db-password".path}"
        ];
      };

      script = ''
        set -euo pipefail

        password_file="$CREDENTIALS_DIRECTORY/db-password"

        # Read the password from systemd credentials.
        # It must be a 64-character hexadecimal value.
        ${pkgs.python3}/bin/python3 - "$password_file" <<'PY' \
          | psql -X -d postgres -v ON_ERROR_STOP=1
        import pathlib
        import sys

        password = pathlib.Path(sys.argv[1]).read_text().strip()

        if len(password) != 64 or any(
            c not in "0123456789abcdefABCDEF"
            for c in password
        ):
            raise SystemExit(
                "Database password must be 64 hexadecimal characters"
            )

        print(
            "ALTER ROLE litellm WITH PASSWORD '" +
            password +
            "';"
        )
        PY
      '';
    };

    # ------------------------------------------------------------
    # LiteLLM container
    # ------------------------------------------------------------

    virtualisation.oci-containers.containers.litellm = {
      image = "ghcr.io/berriai/litellm:main-stable";

      ports = [
        "127.0.0.1:${toString cfg.port}:4000"
      ];

      extraOptions = [
        "--network=ai-backend"
      ];

      volumes = [
        "${litellmConfig}:/app/config.yaml:ro"
        "/run/postgresql:/run/postgresql:ro"
      ];

      environmentFiles = [
        config.sops.secrets."vili/litellm/env".path
      ];

      cmd = [
        "--config"
        "/app/config.yaml"
        "--port"
        "4000"
      ];
    };

    # ------------------------------------------------------------
    # Service dependencies
    # ------------------------------------------------------------

    systemd.services.podman-litellm = {
      requires = [
        "litellm-db-password.service"
      ];

      after = [
        "litellm-db-password.service"
      ];
    };

    # ------------------------------------------------------------
    # Firewall
    # ------------------------------------------------------------

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
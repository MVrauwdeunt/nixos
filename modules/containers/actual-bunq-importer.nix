
{ config, lib, pkgs, ... }:

let
  cfg = config.apps.actual-bunq-importer;

  actualpy = pkgs.python3Packages.callPackage
    ../../pkgs/python/actualpy.nix { };

  python = pkgs.python3.withPackages (_: [
    actualpy
    pkgs.python3Packages.requests
  ]);

  importerSource = pkgs.fetchFromGitHub {
    owner = "mastradus";
    repo = "actual-bunq-importer";
    rev = "3f825938d024ee8ecf196678dda24ffa37dbba21";
    sha256 = "0hyns7wjanzhaga2bz6rmx3zs433rdfzff09jswymf9a7wg4c86m";
  };

  patchedImporter = pkgs.runCommand
    "actual-bunq-importer-patched"
    { nativeBuildInputs = [ pkgs.python3 ]; }
    ''
      mkdir -p "$out"
      cp -r ${importerSource}/. "$out/"
      chmod -R u+w "$out"

      python - "$out" <<'PY'
    import sys
    from pathlib import Path

    root = Path(sys.argv[1])

    def replace_once(filename, old, new):
        path = root / filename
        text = path.read_text()
        count = text.count(old)
        if count != 1:
            raise SystemExit(
                f"{filename}: expected one match, got {count}: {old!r}"
            )
        path.write_text(text.replace(old, new, 1))

    replace_once(
        "bunq_client.py",
        '"permitted_ips": ["*"]',
        '"permitted_ips": [${builtins.toJSON cfg.bunq.allowedIPv4}]',
    )

    replace_once(
        "mapper.py",
        'imported_id = f"bunq-{payment_id}"',
        'imported_id = f"bunq-{actual_account_id}-{payment_id}"',
    )

    replace_once(
        "mapper.py",
        'logger.warning(f"Could not map payment {payment.get('
        + "'id', '?')"
        + '}: {e}")\n        return None',
        'logger.error(f"Could not map payment {payment.get('
        + "'id', '?')"
        + '}: {e}")\n        raise',
    )

    replace_once(
        "sync.py",
        '        if max_payment_id and max_payment_id != (last_id or 0):',
        '        if result["errors"]:\n'
        '            raise RuntimeError('
        'f"Account {bunq_account_id}: "'
        'f"{result['
        + "'errors'"
        + ']} transaction errors; cursor not updated")\n'
        '\n'
        '        if max_payment_id and max_payment_id != (last_id or 0):',
    )

    replace_once(
        "state.py",
        '        with open(self.state_file, "w") as f:\n'
        '            json.dump(self._data, f, indent=2)',
        '        import os\n'
        '        import tempfile\n'
        '        with tempfile.NamedTemporaryFile('
        'mode="w", dir=self.state_file.parent, '
        'prefix=".sync-", delete=False'
        ') as f:\n'
        '            json.dump(self._data, f, indent=2)\n'
        '            f.flush()\n'
        '            os.fsync(f.fileno())\n'
        '            temporary = f.name\n'
        '        os.replace(temporary, self.state_file)',
    )

    print("Upstream safety patches applied.")
    PY

      python -m compileall -q "$out"
    '';

  actualCredentials = [
    "actual-password:${config.sops.secrets."saga/actual_budget_password".path}"
    "actual-encryption-password:${config.sops.secrets."saga/actual_budget_encryption_password".path}"
  ];

  commonServiceConfig = {
    Type = "oneshot";
    DynamicUser = true;
    StateDirectory = "actual-bunq-importer";
    StateDirectoryMode = "0700";
    UMask = "0077";
    PrivateTmp = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    NoNewPrivileges = true;
    RestrictSUIDSGID = true;
  };

  commonAfter = [
    "network-online.target"
    "podman-actual-budget.service"
  ];

  accountProbe = pkgs.writeText "actual-account-check.py" ''
    import os
    from pathlib import Path
    from tempfile import TemporaryDirectory
    from actual import Actual
    from actual.queries import get_accounts

    credentials = Path(os.environ["CREDENTIALS_DIRECTORY"])
    password = (credentials / "actual-password").read_text().rstrip("\n")
    encryption_password = (
        credentials / "actual-encryption-password"
    ).read_text().rstrip("\n")

    with TemporaryDirectory(prefix="actual-check-") as cache:
        with Actual(
            base_url="http://127.0.0.1:${toString cfg.actualPort}",
            password=password,
            file=${builtins.toJSON cfg.budgetName},
            cert=False,
            encryption_password=encryption_password,
            data_dir=cache,
        ) as actual:
            accounts = get_accounts(actual.session)
            print(f"Verbinding geslaagd: {len(accounts)} rekeningen gevonden")
            for account in accounts:
                if not account.closed:
                    print(" - " + account.name)
  '';

  setupRunner = pkgs.writeText "bunq-setup.py" ''
    import json
    import os
    import subprocess
    import tempfile
    from pathlib import Path

    state = Path(os.environ["STATE_DIRECTORY"])
    credentials = Path(os.environ["CREDENTIALS_DIRECTORY"])
    config_path = state / "config.json"

    for directory in ("data", "logs", "actual-cache"):
        (state / directory).mkdir(
            mode=0o700, parents=True, exist_ok=True
        )

    config = (
        json.loads(config_path.read_text())
        if config_path.exists() else {}
    )
    bunq = config.setdefault("bunq", {})

    fields = (
        "installation_token",
        "private_key",
        "server_public_key",
        "device_token",
    )
    if any(bunq.get(key) for key in fields):
        raise SystemExit(
            "bunq registration exists. Refusing to register again."
        )

    def secret(name):
        return (credentials / name).read_text().rstrip("\n")

    bunq.update({
        "api_key": secret("bunq-api-key"),
        "environment": ${builtins.toJSON cfg.bunq.environment},
        "device_description": "saga-actual-bunq-importer",
    })

    config.setdefault("actual", {}).update({
        "url": "http://127.0.0.1:${toString cfg.actualPort}",
        "password": secret("actual-password"),
        "budget_name": ${builtins.toJSON cfg.budgetName},
        "cert": False,
        "encryption_password": secret("actual-encryption-password"),
        "data_dir": str(state / "actual-cache"),
    })

    config.setdefault("sync", {}).update({
        "state_file": str(state / "data" / "sync_state.json"),
        "log_file": str(state / "logs" / "sync.log"),
        "since_date": ${builtins.toJSON cfg.bunq.sinceDate},
    })
    config["sync"].setdefault("account_map", {})
    config["sync"].setdefault("_resolved_account_map", {})

    with tempfile.NamedTemporaryFile(
        mode="w", dir=state, prefix=".config-", delete=False
    ) as f:
        temporary = Path(f.name)
        os.chmod(temporary, 0o600)
        json.dump(config, f, indent=2)
        f.write("\n")

    os.replace(temporary, config_path)

    subprocess.run(
        [
            "${python}/bin/python",
            "${patchedImporter}/sync.py",
            "--setup",
            "--config",
            str(config_path),
        ],
        check=True,
        cwd=state,
    )
  '';

  bunqAccountsProbe = pkgs.writeText "bunq-accounts.py" ''
    import json
    import os
    import sys
    from pathlib import Path

    state = Path(os.environ["STATE_DIRECTORY"])
    config_path = state / "config.json"
    if not config_path.is_file():
        raise SystemExit("Missing bunq registration")

    config = json.loads(config_path.read_text())
    if config.get("bunq", {}).get("environment") != "PRODUCTION":
        raise SystemExit("Unexpected bunq environment")

    sys.path.insert(0, "${patchedImporter}")
    import bunq_client

    session_token, user_id = bunq_client.create_session(config)
    accounts = bunq_client.get_monetary_accounts(
        session_token, user_id
    )

    print(f"{len(accounts)} actieve bunq-rekeningen gevonden")
    for account in accounts:
        print(
            f" - {account.get('description', '(naamloos)')}"
            f" | {account.get('type', 'onbekend')}"
            f" | {account.get('currency', 'onbekend')}"
        )
  '';

  initAccountsRunner = pkgs.writeText "bunq-init-accounts.py" ''
    import json
    import os
    import subprocess
    from pathlib import Path

    state = Path(os.environ["STATE_DIRECTORY"])
    config_path = state / "config.json"
    started = state / "accounts-init-started"
    completed = state / "accounts-init-completed"

    if started.exists() or completed.exists():
        raise SystemExit("Account initialization already started or completed.")
    if not config_path.is_file():
        raise SystemExit("Missing bunq registration")

    config = json.loads(config_path.read_text())
    if config.get("bunq", {}).get("environment") != "PRODUCTION":
        raise SystemExit("Unexpected bunq environment")
    if not config.get("bunq", {}).get("device_token"):
        raise SystemExit("Incomplete bunq registration")
    if not config.get("actual", {}).get("encryption_password"):
        raise SystemExit("Missing Actual encryption password")

    with started.open("x") as f:
        f.write("started\n")
    os.chmod(started, 0o600)

    subprocess.run(
        [
            "${python}/bin/python",
            "${patchedImporter}/sync.py",
            "--init-accounts",
            "--config",
            str(config_path),
        ],
        check=True,
        cwd=state,
    )

    with completed.open("x") as f:
        f.write("completed\n")
    os.chmod(completed, 0o600)
    started.unlink()
    print("Actual account initialization completed.")
  '';

  historyRunner = pkgs.writeText "bunq-history.py" ''
    import json
    import os
    import subprocess
    import tempfile
    from pathlib import Path

    state = Path(os.environ["STATE_DIRECTORY"])
    config_path = state / "config.json"
    started = state / "history-import-started"
    completed = state / "history-import-completed"

    if started.exists() or completed.exists():
        raise SystemExit("Historical import already started or completed.")
    if not config_path.is_file():
        raise SystemExit("Missing bunq registration")

    config = json.loads(config_path.read_text())
    bunq = config.get("bunq", {})
    actual = config.get("actual", {})
    sync = config.get("sync", {})

    for key in (
        "api_key", "installation_token", "private_key", "device_token"
    ):
        if not bunq.get(key):
            raise SystemExit(f"Missing bunq field: {key}")

    if bunq.get("environment") != "PRODUCTION":
        raise SystemExit("Unexpected bunq environment")
    if actual.get("budget_name") != ${builtins.toJSON cfg.budgetName}:
        raise SystemExit("Unexpected Actual budget")
    if actual.get("url") != "http://127.0.0.1:${toString cfg.actualPort}":
        raise SystemExit("Unexpected Actual server")
    if not actual.get("password") or not actual.get("encryption_password"):
        raise SystemExit("Missing Actual credentials")
    if not sync.get("account_map"):
        raise SystemExit("No account mappings found")

    state_file = Path(sync["state_file"])
    if state_file.exists():
        raise SystemExit("Sync state already exists")

    sync["since_date"] = None

    with tempfile.NamedTemporaryFile(
        mode="w", dir=state, prefix=".config-", delete=False
    ) as f:
        temporary = Path(f.name)
        os.chmod(temporary, 0o600)
        json.dump(config, f, indent=2)
        f.write("\n")
        f.flush()
        os.fsync(f.fileno())
    os.replace(temporary, config_path)

    with started.open("x") as f:
        f.write("started\n")
    os.chmod(started, 0o600)

    subprocess.run(
        [
            "${python}/bin/python",
            "${patchedImporter}/sync.py",
            "--full",
            "--config",
            str(config_path),
        ],
        check=True,
        cwd=state,
    )

    with completed.open("x") as f:
        f.write("completed\n")
    os.chmod(completed, 0o600)
    started.unlink()
    print("Historical import completed.")
  '';

  # NEW: incremental sync. Never re-runs --full.
  syncRunner = pkgs.writeText "bunq-incremental-sync.py" ''
    import fcntl
    import json
    import os
    import subprocess
    from pathlib import Path

    state = Path(os.environ["STATE_DIRECTORY"])
    config_path = state / "config.json"

    # Serialize manual and timer-triggered runs.
    with (state / "sync.lock").open("a+") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)

        if not (state / "history-import-completed").exists():
            raise SystemExit(
                "Historical import not completed. Refusing incremental sync."
            )

        if not config_path.is_file():
            raise SystemExit("Missing bunq registration")

        config = json.loads(config_path.read_text())
        bunq = config.get("bunq", {})
        actual = config.get("actual", {})
        sync = config.get("sync", {})

        if bunq.get("environment") != "PRODUCTION":
            raise SystemExit("Unexpected bunq environment")

        if not bunq.get("installation_token") or not bunq.get("api_key"):
            raise SystemExit("Incomplete bunq registration")

        if actual.get("budget_name") != ${builtins.toJSON cfg.budgetName}:
            raise SystemExit("Unexpected Actual budget")

        if actual.get("url") != "http://127.0.0.1:${toString cfg.actualPort}":
            raise SystemExit("Unexpected Actual server")

        if not sync.get("account_map"):
            raise SystemExit("Missing account mappings")

        # The historical import removed the date filter.
        if sync.get("since_date") is not None:
            raise SystemExit("Unexpected date filter in sync configuration")

        state_file = Path(sync["state_file"])
        if not state_file.is_file():
            raise SystemExit("Missing incremental sync state")

        cursors = json.loads(state_file.read_text())
        if not cursors:
            raise SystemExit("Incremental sync state is empty")

        print("Starting incremental bunq sync...", flush=True)

        subprocess.run(
            [
                "${python}/bin/python",
                "${patchedImporter}/sync.py",
                "--config",
                str(config_path),
            ],
            check=True,
            cwd=state,
        )

        print("Incremental bunq sync completed.", flush=True)
  '';

in
{
  options.apps.actual-bunq-importer = {
    enable = lib.mkEnableOption "Actual Budget bunq integration";

    actualPort = lib.mkOption {
      type = lib.types.port;
      default = 5006;
    };

    budgetName = lib.mkOption {
      type = lib.types.str;
      default = "My Finances";
    };

    sopsFile = lib.mkOption {
      type = lib.types.path;
      default = ../../secrets.yaml;
    };

    bunq = {
      enable = lib.mkEnableOption "bunq API integration";

      environment = lib.mkOption {
        type = lib.types.enum [ "SANDBOX" "PRODUCTION" ];
        default = "SANDBOX";
      };

      allowedIPv4 = lib.mkOption {
        type = lib.types.strMatching
          "([0-9]{1,3}\\.){3}[0-9]{1,3}";
        default = "185.238.128.199";
      };

      sinceDate = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.strMatching "[0-9]{4}-[0-9]{2}-[0-9]{2}"
        );
        default = null;
      };

      # NEW: keep disabled until manual sync succeeds.
      autoSync = lib.mkEnableOption
        "automatic bunq synchronization every 30 minutes";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      sops.secrets = {
        "saga/actual_budget_password".sopsFile = cfg.sopsFile;
        "saga/actual_budget_encryption_password".sopsFile = cfg.sopsFile;
      };

      systemd.services.actual-bunq-importer-check = {
        description = "Actual Budget account read test";
        after = commonAfter;
        wants = [ "network-online.target" ];

        serviceConfig = {
          Type = "oneshot";
          DynamicUser = true;
          UMask = "0077";
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          NoNewPrivileges = true;
          RestrictSUIDSGID = true;
          LoadCredential = actualCredentials;
          ExecStart = "${python}/bin/python ${accountProbe}";
        };
      };
    }

    (lib.mkIf cfg.bunq.enable {
      assertions = [{
        assertion = cfg.bunq.environment == "PRODUCTION";
        message = "bunq importer supports PRODUCTION only.";
      }];

      sops.secrets."saga/bunq_api_key".sopsFile = cfg.sopsFile;

      systemd.services.actual-bunq-importer-setup = {
        description = "Register bunq API device (manual only)";
        after = commonAfter;
        wants = [ "network-online.target" ];

        serviceConfig = commonServiceConfig // {
          LoadCredential = actualCredentials ++ [
            "bunq-api-key:${config.sops.secrets."saga/bunq_api_key".path}"
          ];
          ExecStart = "${python}/bin/python ${setupRunner}";
        };
      };

      systemd.services.actual-bunq-importer-accounts = {
        description = "List bunq accounts (manual only)";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        serviceConfig = commonServiceConfig // {
          ExecStart = "${python}/bin/python ${bunqAccountsProbe}";
        };
      };

      systemd.services.actual-bunq-importer-init-accounts = {
        description = "Create Actual accounts from bunq (manual only)";
        after = commonAfter;
        wants = [ "network-online.target" ];

        serviceConfig = commonServiceConfig // {
          ExecStart = "${python}/bin/python ${initAccountsRunner}";
        };
      };

      systemd.services.actual-bunq-importer-history = {
        description = "One-time complete bunq payment history import";
        after = commonAfter;
        wants = [ "network-online.target" ];

        serviceConfig = commonServiceConfig // {
          TimeoutStartSec = "infinity";
          ExecStart = "${python}/bin/python ${historyRunner}";
        };
      };

      # NEW: manually runnable incremental sync.
      systemd.services.actual-bunq-importer-sync = {
        description = "Incremental bunq to Actual Budget sync";
        after = commonAfter;
        wants = [ "network-online.target" ];

        serviceConfig = commonServiceConfig // {
          TimeoutStartSec = "30min";
          ExecStart = "${python}/bin/python ${syncRunner}";
        };
      };

      # NEW: optional automatic timer.
      systemd.timers.actual-bunq-importer-sync = {
        description = "Automatic bunq sync every 30 minutes";

        wantedBy = lib.optionals cfg.bunq.autoSync [
          "timers.target"
        ];

        timerConfig = {
          OnCalendar = "*:0/30";
          Persistent = true;
          RandomizedDelaySec = "2min";
          Unit = "actual-bunq-importer-sync.service";
        };
      };
    })
  ]);
}

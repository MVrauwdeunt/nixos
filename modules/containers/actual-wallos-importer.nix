
{ config, lib, pkgs, ... }:

let
  cfg = config.apps.actual-wallos-importer;

  actualpy = pkgs.python3Packages.callPackage
    ../../pkgs/python/actualpy.nix { };

  python = pkgs.python3.withPackages (_: [ actualpy ]);

  importer = pkgs.writeText "actual-wallos-sync.py" ''
    import copy
    import json
    import os
    import re
    import sys
    import urllib.parse
    import urllib.request

    from datetime import date
    from decimal import Decimal, InvalidOperation
    from pathlib import Path
    from tempfile import TemporaryDirectory

    from actual import Actual
    from actual.queries import (
        get_accounts,
        get_schedules,
        get_rules,
        create_schedule,
        create_schedule_config,
    )

    mode = sys.argv[1] if len(sys.argv) > 1 else "preview"

    if mode not in ("preview", "sync"):
        raise SystemExit("Usage: importer.py preview|sync")

    creds = Path(os.environ["CREDENTIALS_DIRECTORY"])

    def secret(name):
        return (creds / name).read_text().rstrip("\n")

    allowed_accounts = set(
        json.loads(${builtins.toJSON
          (builtins.toJSON cfg.allowedAccounts)})
    )

    frequency_map = {
        1: "daily",
        2: "weekly",
        3: "monthly",
        4: "yearly",
    }

    wallos_pattern = re.compile(r"^Wallos \[([^\]]+)\] ")

    # --------------------------------------------------
    # Wallos
    # --------------------------------------------------

    url = (
        "http://127.0.0.1:${toString cfg.wallosPort}"
        "/api/subscriptions/get_subscriptions.php"
    )

    body = urllib.parse.urlencode({
        "api_key": secret("wallos-api-key"),
    }).encode()

    request = urllib.request.Request(
        url,
        data=body,
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept": "application/json",
        },
        method="POST",
    )

    with urllib.request.urlopen(request, timeout=30) as response:
        result = json.load(response)

    if (
        not isinstance(result, dict)
        or result.get("success") is not True
        or not isinstance(result.get("subscriptions"), list)
    ):
        raise SystemExit("Invalid Wallos API response")

    planned = {}
    seen_names = set()

    for item in result["subscriptions"]:
        if str(item.get("inactive", 0)).lower() in ("1", "true"):
            continue

        identifier = str(item.get("id") or "").strip()
        name = str(item.get("name") or "").strip()

        if not identifier or not name:
            raise SystemExit("Missing Wallos subscription ID or name")

        if identifier in planned:
            raise SystemExit(f"Duplicate Wallos ID: {identifier}")

        target_name = f"Wallos [{identifier}] {name}"

        if target_name in seen_names:
            raise SystemExit(f"Duplicate schedule name: {target_name}")

        seen_names.add(target_name)

        account_name = str(
            item.get("payment_method_name") or ""
        ).strip()

        if account_name not in allowed_accounts:
            raise SystemExit(
                f"Invalid payment method for {target_name}: "
                f"{account_name!r}"
            )

        try:
            amount = Decimal(
                str(item["price"]).replace(",", ".")
            )
            cycle = int(item["cycle"])
            interval = int(item["frequency"])
            start = date.fromisoformat(
                str(item["next_payment"])
            )
        except (
            KeyError, TypeError, ValueError, InvalidOperation
        ) as exc:
            raise SystemExit(
                f"Invalid Wallos data for {target_name}: {exc}"
            )

        if (
            not amount.is_finite()
            or amount <= 0
            or amount != amount.quantize(Decimal("0.01"))
        ):
            raise SystemExit(f"Invalid amount for {target_name}")

        if cycle not in frequency_map or interval < 1:
            raise SystemExit(f"Invalid recurrence for {target_name}")

        planned[identifier] = {
            "id": identifier,
            "name": target_name,
            "account_name": account_name,
            "amount": amount,
            "amount_cents": -int(amount * 100),
            "start": start,
            "interval": interval,
            "frequency": frequency_map[cycle],
        }

    if not planned:
        raise SystemExit(
            "No active subscriptions; refusing to synchronize"
        )

    # --------------------------------------------------
    # Helpers
    # --------------------------------------------------

    def read_conditions(rule):
        raw = rule.conditions

        if isinstance(raw, str):
            conditions = json.loads(raw)
        elif isinstance(raw, list):
            conditions = copy.deepcopy(raw)
        else:
            raise ValueError(
                f"Unsupported conditions type: {type(raw)}"
            )

        if not isinstance(conditions, list):
            raise ValueError("Invalid rule conditions")

        return conditions

    def write_conditions(rule, conditions):
        if isinstance(rule.conditions, str):
            rule.conditions = json.dumps(
                conditions, separators=(",", ":")
            )
        else:
            rule.conditions = conditions

    def get_condition(conditions, field):
        matches = [
            condition for condition in conditions
            if condition.get("field") == field
        ]

        if len(matches) != 1:
            raise ValueError(
                f"Expected exactly one {field} condition, "
                f"found {len(matches)}"
            )

        return matches[0]

    def recurrence(item):
        return create_schedule_config(
            start=item["start"],
            interval=item["interval"],
            frequency=item["frequency"],
            end_mode="never",
        )

    def desired_recurrence(item, existing):
        updated = copy.deepcopy(existing)

        if not isinstance(updated, dict):
            raise ValueError("Invalid date recurrence")

        updated["start"] = item["start"].isoformat()
        updated["interval"] = item["interval"]
        updated["frequency"] = item["frequency"]

        # Preserve Actual-specific recurrence settings.
        # Do not overwrite patterns, weekend handling, etc.
        return updated

    def schedule_id_from_name(name):
        match = wallos_pattern.match(name or "")
        return match.group(1) if match else None

    def validate_rule(schedule, rule):
        if rule is None:
            raise ValueError(
                f"No rule found for {schedule.name}"
            )

        conditions = read_conditions(rule)

        amount_condition = get_condition(
            conditions, "amount"
        )
        account_condition = get_condition(
            conditions, "acct"
        )
        date_condition = get_condition(
            conditions, "date"
        )

        if (
            amount_condition.get("op") != "is"
            or account_condition.get("op") != "is"
            or date_condition.get("op") != "isapprox"
        ):
            raise ValueError(
                f"Unexpected rule structure: {schedule.name}"
            )

        actions = (
            json.loads(rule.actions)
            if isinstance(rule.actions, str)
            else rule.actions
        )

        if (
            not isinstance(actions, list)
            or len(actions) != 1
            or actions[0].get("op") != "link-schedule"
            or str(actions[0].get("value")) != str(schedule.id)
        ):
            raise ValueError(
                f"Unexpected schedule action: {schedule.name}"
            )

        if bool(schedule.posts_transaction):
            raise ValueError(
                f"Auto-post is enabled for {schedule.name}; "
                "refusing modification"
            )

        return (
            conditions,
            amount_condition,
            account_condition,
            date_condition,
        )

    # --------------------------------------------------
    # Actual Budget
    # --------------------------------------------------

    with TemporaryDirectory(prefix="wallos-actual-") as cache:
        with Actual(
            base_url="http://127.0.0.1:${toString cfg.actualPort}",
            password=secret("actual-password"),
            file=${builtins.toJSON cfg.budgetName},
            encryption_password=secret(
                "actual-encryption-password"
            ),
            data_dir=cache,
        ) as actual:

            accounts = get_accounts(actual.session)
            schedules = get_schedules(actual.session)
            rules = get_rules(actual.session)

            account_map = {}

            for account in accounts:
                name = (account.name or "").strip()

                if not name:
                    continue

                if name in account_map:
                    raise SystemExit(
                        f"Duplicate Actual account name: {name}"
                    )

                account_map[name] = account

            for item in planned.values():
                if item["account_name"] not in account_map:
                    raise SystemExit(
                        "Actual account missing: "
                        + item["account_name"]
                    )

            rule_map = {
                str(rule.id): rule
                for rule in rules
            }

            existing = {}

            for schedule in schedules:
                identifier = schedule_id_from_name(
                    schedule.name
                )

                if identifier is None:
                    continue

                if identifier in existing:
                    raise SystemExit(
                        f"Duplicate Actual Wallos ID: {identifier}"
                    )

                existing[identifier] = schedule

            changes = []
            new_items = []
            removed_ids = []

            # --------------------------------------------------
            # Compare, without modifying anything yet
            # --------------------------------------------------

            for identifier, item in planned.items():
                schedule = existing.get(identifier)

                if schedule is None:
                    new_items.append(item)
                    print(
                        f"[CREATE] {item['name']} "
                        f"EUR {item['amount']:.2f} "
                        f"account={item['account_name']}",
                        flush=True,
                    )
                    continue

                rule = rule_map.get(str(schedule.rule_id))

                try:
                    conditions, amount_cond, account_cond, date_cond = (
                        validate_rule(schedule, rule)
                    )
                except ValueError as exc:
                    raise SystemExit(str(exc))

                account_id = str(
                    account_map[item["account_name"]].id
                )

                wanted_date = desired_recurrence(
                    item, date_cond["value"]
                )

                differences = []

                if schedule.name != item["name"]:
                    differences.append("name")

                if amount_cond["value"] != item["amount_cents"]:
                    differences.append("amount")

                if str(account_cond["value"]) != account_id:
                    differences.append("account")

                date_value = date_cond["value"]

                for field in ("start", "interval", "frequency"):
                    if date_value.get(field) != wanted_date[field]:
                        differences.append(f"date.{field}")

                if differences:
                    changes.append({
                        "schedule": schedule,
                        "rule": rule,
                        "conditions": conditions,
                        "item": item,
                        "account_id": account_id,
                        "wanted_date": wanted_date,
                    })

                    print(
                        f"[UPDATE] {item['name']}: "
                        + ", ".join(differences),
                        flush=True,
                    )
                else:
                    print(
                        f"[OK] {item['name']}",
                        flush=True,
                    )

            for identifier, schedule in existing.items():
                if identifier not in planned:
                    removed_ids.append(identifier)
                    print(
                        f"[REVIEW] No longer active in Wallos: "
                        f"{schedule.name}",
                        flush=True,
                    )

            print()
            print(f"Create: {len(new_items)}")
            print(f"Update: {len(changes)}")
            print(f"Unchanged: {len(planned) - len(new_items) - len(changes)}")
            print(f"Inactive/missing: {len(removed_ids)}")

            if mode == "preview":
                print("READ ONLY: no changes saved", flush=True)
                sys.exit(0)

            # --------------------------------------------------
            # Apply validated changes
            # --------------------------------------------------

            for change in changes:
                schedule = change["schedule"]
                rule = change["rule"]
                item = change["item"]

                conditions = change["conditions"]

                get_condition(
                    conditions, "amount"
                )["value"] = item["amount_cents"]

                get_condition(
                    conditions, "acct"
                )["value"] = change["account_id"]

                get_condition(
                    conditions, "date"
                )["value"] = change["wanted_date"]

                write_conditions(rule, conditions)
                schedule.name = item["name"]

            for item in new_items:
                create_schedule(
                    actual.session,
                    date=recurrence(item),
                    amount=-item["amount"],
                    amount_operation="is",
                    name=item["name"],
                    account=account_map[item["account_name"]],
                    posts_transaction=False,
                )

            if changes or new_items:
                actual.commit()

            print(
                f"SYNC FINISHED: "
                f"{len(new_items)} created, "
                f"{len(changes)} updated",
                flush=True,
            )
            print(
                "Automatic transaction posting: disabled",
                flush=True,
            )
  '';

  credentials = [
    "wallos-api-key:${config.sops.secrets."saga/wallos_api_key".path}"
    "actual-password:${config.sops.secrets."saga/actual_budget_password".path}"
    "actual-encryption-password:${config.sops.secrets."saga/actual_budget_encryption_password".path}"
  ];

  serviceBase = {
    after = [
      "network-online.target"
      "podman-wallos.service"
      "podman-actual-budget.service"
    ];

    wants = [
      "network-online.target"
    ];

    serviceConfig = {
      Type = "oneshot";
      DynamicUser = true;
      UMask = "0077";

      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      NoNewPrivileges = true;
      RestrictSUIDSGID = true;

      LoadCredential = credentials;
    };
  };

in
{
  options.apps.actual-wallos-importer = {
    enable = lib.mkEnableOption
      "Wallos to Actual Budget synchronization";

    wallosPort = lib.mkOption {
      type = lib.types.port;
      default = 8282;
    };

    actualPort = lib.mkOption {
      type = lib.types.port;
      default = 5006;
    };

    budgetName = lib.mkOption {
      type = lib.types.str;
      default = "My Finances";
    };

    allowedAccounts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "Inkomen/Vaste Lasten"
        "Betaalrekening"
      ];
    };

    autoSync = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description =
        "Enable daily Wallos to Actual synchronization";
    };

    sopsFile = lib.mkOption {
      type = lib.types.path;
      default = ../../secrets.yaml;
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."saga/wallos_api_key".sopsFile =
      cfg.sopsFile;

    systemd.services.actual-wallos-preview =
      lib.recursiveUpdate serviceBase {
        description =
          "Preview Wallos to Actual schedule changes";

        serviceConfig.ExecStart =
          "${python}/bin/python ${importer} preview";
      };

    systemd.services.actual-wallos-import =
      lib.recursiveUpdate serviceBase {
        description =
          "Synchronize Wallos subscriptions to Actual Budget";

        serviceConfig.ExecStart =
          "${python}/bin/python ${importer} sync";
      };

    systemd.timers.actual-wallos-import =
      lib.mkIf cfg.autoSync {
        wantedBy = [ "timers.target" ];

        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
          RandomizedDelaySec = "15m";
          Unit = "actual-wallos-import.service";
        };
      };
  };
}

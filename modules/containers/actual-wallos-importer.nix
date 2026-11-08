
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
        get_categories,
        get_category_groups,
        create_category,
        create_category_group,
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

    category_group = ${builtins.toJSON cfg.categoryGroup};

    frequency_map = {
        1: "daily",
        2: "weekly",
        3: "monthly",
        4: "yearly",
    }

    wallos_pattern = re.compile(r"^Wallos \[([^\]]+)\] ")

    # --------------------------------------------------
    # Wallos API
    # --------------------------------------------------

    base_url = "http://127.0.0.1:${toString cfg.wallosPort}"

    def wallos_request(endpoint):
        body = urllib.parse.urlencode({
            "api_key": secret("wallos-api-key"),
        }).encode()

        request = urllib.request.Request(
            base_url + endpoint,
            data=body,
            headers={
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "application/json",
            },
            method="POST",
        )

        with urllib.request.urlopen(
            request, timeout=30
        ) as response:
            result = json.load(response)

        if (
            not isinstance(result, dict)
            or result.get("success") is not True
        ):
            raise SystemExit(
                f"Invalid Wallos API response: {endpoint}"
            )

        return result

    subscriptions_response = wallos_request(
        "/api/subscriptions/get_subscriptions.php"
    )

    categories_response = wallos_request(
        "/api/categories/get_categories.php"
    )

    subscriptions = subscriptions_response.get(
        "subscriptions"
    )

    wallos_categories_raw = categories_response.get(
        "categories"
    )

    if not isinstance(subscriptions, list):
        raise SystemExit("Invalid Wallos subscription list")

    if not isinstance(wallos_categories_raw, list):
        raise SystemExit("Invalid Wallos category list")

    if not wallos_categories_raw:
        raise SystemExit(
            "Wallos returned no categories; refusing sync"
        )

    # --------------------------------------------------
    # Wallos categories
    # --------------------------------------------------

    wallos_categories = {}
    wallos_category_ids = {}

    for category in wallos_categories_raw:
        identifier = str(
            category.get("id") or ""
        ).strip()

        name = str(
            category.get("name") or ""
        ).strip()

        if not identifier or not name:
            raise SystemExit(
                "Invalid Wallos category"
            )

        if name in wallos_categories:
            raise SystemExit(
                f"Duplicate Wallos category name: {name}"
            )

        if identifier in wallos_category_ids:
            raise SystemExit(
                f"Duplicate Wallos category ID: {identifier}"
            )

        wallos_categories[name] = identifier
        wallos_category_ids[identifier] = name

    # --------------------------------------------------
    # Wallos subscriptions
    # --------------------------------------------------

    planned = {}
    seen_names = set()
    inactive_ids = set()

    for item in subscriptions:
        identifier = str(
            item.get("id") or ""
        ).strip()

        name = str(
            item.get("name") or ""
        ).strip()

        if not identifier or not name:
            raise SystemExit(
                "Missing Wallos subscription ID or name"
            )

        if (
            identifier in planned
            or identifier in inactive_ids
        ):
            raise SystemExit(
                f"Duplicate Wallos subscription ID: {identifier}"
            )

        if str(
            item.get("inactive", 0)
        ).lower() in ("1", "true"):
            inactive_ids.add(identifier)
            continue

        target_name = f"Wallos [{identifier}] {name}"

        if target_name in seen_names:
            raise SystemExit(
                f"Duplicate schedule name: {target_name}"
            )

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
            KeyError,
            TypeError,
            ValueError,
            InvalidOperation,
        ) as exc:
            raise SystemExit(
                f"Invalid Wallos data for {target_name}: {exc}"
            )

        if (
            not amount.is_finite()
            or amount <= 0
            or amount != amount.quantize(
                Decimal("0.01")
            )
        ):
            raise SystemExit(
                f"Invalid amount for {target_name}"
            )

        if cycle not in frequency_map or interval < 1:
            raise SystemExit(
                f"Invalid recurrence for {target_name}"
            )

        category_id = str(
            item.get("category_id") or ""
        ).strip()

        category_name = str(
            item.get("category_name") or ""
        ).strip()

        if category_id not in wallos_category_ids:
            raise SystemExit(
                f"Unknown Wallos category ID for "
                f"{target_name}: {category_id!r}"
            )

        expected_name = wallos_category_ids[category_id]

        if category_name != expected_name:
            raise SystemExit(
                f"Wallos category mismatch for "
                f"{target_name}: "
                f"{category_name!r} != {expected_name!r}"
            )

        planned[identifier] = {
            "id": identifier,
            "name": target_name,
            "account_name": account_name,
            "amount": amount,
            "amount_cents": -int(amount * 100),
            "start": start,
            "interval": interval,
            "frequency": frequency_map[cycle],
            "category_name": category_name,
        }

    if not planned:
        raise SystemExit(
            "No active subscriptions; refusing sync"
        )

    print(
        f"Wallos: {len(planned)} active subscriptions",
        flush=True,
    )

    print(
        f"Wallos: {len(wallos_categories)} categories",
        flush=True,
    )

    # --------------------------------------------------
    # Helpers
    # --------------------------------------------------

    def read_json(value):
        if isinstance(value, str):
            return json.loads(value)

        return copy.deepcopy(value)

    def write_json(original, value):
        if isinstance(original, str):
            return json.dumps(
                value,
                separators=(",", ":"),
            )

        return value

    def get_condition(conditions, field):
        matches = [
            condition
            for condition in conditions
            if isinstance(condition, dict)
            and condition.get("field") == field
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
            raise ValueError(
                "Invalid date recurrence"
            )

        updated["start"] = item["start"].isoformat()
        updated["interval"] = item["interval"]
        updated["frequency"] = item["frequency"]

        return updated

    def schedule_id_from_name(name):
        match = wallos_pattern.match(name or "")
        return match.group(1) if match else None

    def validate_rule(schedule, rule):
        if rule is None:
            raise ValueError(
                f"No rule found for {schedule.name}"
            )

        conditions = read_json(rule.conditions)
        actions = read_json(rule.actions)

        if not isinstance(conditions, list):
            raise ValueError(
                f"Invalid conditions: {schedule.name}"
            )

        if (
            not isinstance(actions, list)
            or not all(
                isinstance(action, dict)
                for action in actions
            )
        ):
            raise ValueError(
                f"Invalid actions: {schedule.name}"
            )

        amount_condition = get_condition(
            conditions, "amount"
        )

        account_condition = get_condition(
            conditions, "acct"
        )

        date_condition = get_condition(
            conditions, "date"
        )

        # Diagnose operators without logging values,
        # account IDs, or other sensitive data.
        expected_operators = {
            "amount": "is",
            "acct": "is",
            "date": "isapprox",
        }

        actual_operators = {
            "amount": amount_condition.get("op"),
            "acct": account_condition.get("op"),
            "date": date_condition.get("op"),
        }

        unexpected = {
            field: {
                "expected": expected_op,
                "actual": actual_operators[field],
            }
            for field, expected_op in expected_operators.items()
            if actual_operators[field] != expected_op
        }

        if unexpected:
            fields = [
                condition.get("field")
                if isinstance(condition, dict)
                else "<invalid>"
                for condition in conditions
            ]

            raise ValueError(
                f"Unexpected rule structure: {schedule.name}; "
                f"operator mismatches: {unexpected!r}; "
                f"condition fields: {fields!r}"
            )

        links = [
            action
            for action in actions
            if action.get("op") == "link-schedule"
        ]

        category_actions = [
            action
            for action in actions
            if action.get("field") == "category"
        ]

        if (
            len(links) != 1
            or str(links[0].get("value"))
                != str(schedule.id)
            or len(category_actions) > 1
            or any(
                action.get("op") != "set"
                for action in category_actions
            )
        ):
            raise ValueError(
                f"Unexpected schedule actions: "
                f"{schedule.name}"
            )

        if bool(schedule.posts_transaction):
            raise ValueError(
                f"Auto-post is enabled for {schedule.name}; "
                "refusing modification"
            )

        return (
            conditions,
            actions,
            amount_condition,
            account_condition,
            date_condition,
        )

    def desired_actions(actions, category_id):
        updated = [
            copy.deepcopy(action)
            for action in actions
            if action.get("field") != "category"
        ]

        if category_id is not None:
            updated.append({
                "op": "set",
                "field": "category",
                "value": category_id,
                "type": "id",
                "options": {
                    "splitIndex": 0,
                },
            })

        return updated

    def category_action_values(actions):
        return [
            str(action.get("value"))
            for action in actions
            if action.get("field") == "category"
        ]

    # --------------------------------------------------
    # Actual Budget
    # --------------------------------------------------

    with TemporaryDirectory(
        prefix="wallos-actual-"
    ) as cache:

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

            categories = get_categories(actual.session)

            category_groups = get_category_groups(
                actual.session
            )

            # ------------------------------------------
            # Actual categories
            # ------------------------------------------

            actual_categories = {}

            for category in categories:
                name = (
                    category.name or ""
                ).strip()

                if not name:
                    continue

                if name in actual_categories:
                    raise SystemExit(
                        f"Duplicate Actual category name: {name}"
                    )

                actual_categories[name] = category

            group_exists = any(
                group.name == category_group
                for group in category_groups
            )

            new_categories = []

            for name in wallos_categories:
                if name not in actual_categories:
                    new_categories.append(name)

                    print(
                        f"[CATEGORY CREATE] {name}",
                        flush=True,
                    )
                else:
                    print(
                        f"[CATEGORY OK] {name}",
                        flush=True,
                    )

            if new_categories and not group_exists:
                print(
                    f"[GROUP CREATE] {category_group}",
                    flush=True,
                )

            # ------------------------------------------
            # Accounts
            # ------------------------------------------

            account_map = {}

            for account in accounts:
                name = (
                    account.name or ""
                ).strip()

                if not name:
                    continue

                if name in account_map:
                    raise SystemExit(
                        f"Duplicate Actual account: {name}"
                    )

                account_map[name] = account

            for item in planned.values():
                if item["account_name"] not in account_map:
                    raise SystemExit(
                        f"Actual account missing: "
                        f"{item['account_name']}"
                    )

            # ------------------------------------------
            # Existing schedules
            # ------------------------------------------

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
                        f"Duplicate Actual Wallos ID: "
                        f"{identifier}"
                    )

                existing[identifier] = schedule

            # ------------------------------------------
            # Category placeholders
            # ------------------------------------------

            def category_name_for(item):
                name = item["category_name"]

                if name in (
                    "Geen categorie",
                    "No category",
                ):
                    return None

                return name

            def resolve_category_id(name):
                if name is None:
                    return None

                category = actual_categories.get(name)

                if category is None:
                    raise ValueError(
                        f"Actual category missing: {name}"
                    )

                return str(category.id)

            changes = []
            new_items = []
            removed_ids = []

            # Track existing rules intentionally skipped
            # because their structure is not safe to edit.
            skipped_items = []

            # ------------------------------------------
            # Compare schedules
            # ------------------------------------------

            for identifier, item in planned.items():
                category_name = category_name_for(item)

                schedule = existing.get(identifier)

                if schedule is None:
                    new_items.append(item)

                    print(
                        f"[CREATE] {item['name']} "
                        f"EUR {item['amount']:.2f} "
                        f"category={category_name or 'None'}",
                        flush=True,
                    )
                    continue

                rule = rule_map.get(
                    str(schedule.rule_id)
                )

                try:
                    (
                        conditions,
                        actions,
                        amount_cond,
                        account_cond,
                        date_cond,
                    ) = validate_rule(schedule, rule)

                except (ValueError, TypeError, KeyError) as exc:
                    # A manually modified or unexpected
                    # existing rule must not block the
                    # synchronization of other subscriptions.
                    #
                    # Do not modify or recreate this schedule.
                    skipped_items.append({
                        "id": identifier,
                        "name": item["name"],
                        "reason": str(exc),
                    })

                    print(
                        f"[SKIP] {item['name']}: {exc}",
                        flush=True,
                    )

                    continue

                account_id = str(
                    account_map[item["account_name"]].id
                )

                wanted_date = desired_recurrence(
                    item,
                    date_cond["value"],
                )

                current_category = category_action_values(
                    actions
                )

                if category_name is None:
                    category_changed = bool(
                        current_category
                    )

                elif category_name in actual_categories:
                    category_id = resolve_category_id(
                        category_name
                    )

                    category_changed = (
                        current_category != [category_id]
                    )
                else:
                    category_changed = True

                differences = []

                if category_changed:
                    differences.append("category")

                if schedule.name != item["name"]:
                    differences.append("name")

                if (
                    amount_cond["value"]
                    != item["amount_cents"]
                ):
                    differences.append("amount")

                if (
                    str(account_cond["value"])
                    != account_id
                ):
                    differences.append("account")

                for field in (
                    "start",
                    "interval",
                    "frequency",
                ):
                    if (
                        date_cond["value"].get(field)
                        != wanted_date[field]
                    ):
                        differences.append(
                            f"date.{field}"
                        )

                if differences:
                    changes.append({
                        "schedule": schedule,
                        "rule": rule,
                        "conditions": conditions,
                        "actions": actions,
                        "item": item,
                        "account_id": account_id,
                        "wanted_date": wanted_date,
                        "category_name": category_name,
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

            # ------------------------------------------
            # Inactive / removed
            # ------------------------------------------

            for identifier, schedule in existing.items():
                if identifier not in planned:
                    removed_ids.append(identifier)

                    reason = (
                        "inactive"
                        if identifier in inactive_ids
                        else "missing"
                    )

                    print(
                        f"[REVIEW] {schedule.name}: "
                        f"{reason} in Wallos",
                        flush=True,
                    )

            # ------------------------------------------
            # Summary
            # ------------------------------------------

            unchanged_count = (
                len(planned)
                - len(new_items)
                - len(changes)
                - len(skipped_items)
            )

            print()
            print(
                f"Categories to create: "
                f"{len(new_categories)}"
            )
            print(
                f"Schedules to create: {len(new_items)}"
            )
            print(
                f"Schedules to update: {len(changes)}"
            )
            print(
                f"Unchanged: {unchanged_count}"
            )
            print(
                f"Skipped (protected): "
                f"{len(skipped_items)}"
            )
            print(
                f"Inactive/missing: {len(removed_ids)}"
            )

            if skipped_items:
                print()
                print(
                    "Protected schedules left untouched:",
                    flush=True,
                )

                for skipped in skipped_items:
                    print(
                        f"  - {skipped['name']}",
                        flush=True,
                    )

            if mode == "preview":
                print(
                    "READ ONLY: no changes saved",
                    flush=True,
                )
                sys.exit(0)

            # ------------------------------------------
            # Create categories
            # ------------------------------------------

            if new_categories and not group_exists:
                create_category_group(
                    actual.session,
                    category_group,
                )

            for name in new_categories:
                category = create_category(
                    actual.session,
                    name=name,
                    group_name=category_group,
                )

                actual_categories[name] = category

                print(
                    f"[CATEGORY CREATED] {name}",
                    flush=True,
                )

            # ------------------------------------------
            # Update existing schedules
            # ------------------------------------------

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

                category_id = resolve_category_id(
                    change["category_name"]
                )

                updated_actions = desired_actions(
                    change["actions"],
                    category_id,
                )

                rule.conditions = write_json(
                    rule.conditions,
                    conditions,
                )

                rule.actions = write_json(
                    rule.actions,
                    updated_actions,
                )

                schedule.name = item["name"]

            # ------------------------------------------
            # Create schedules
            # ------------------------------------------

            for item in new_items:
                schedule = create_schedule(
                    actual.session,
                    date=recurrence(item),
                    amount=-item["amount"],
                    amount_operation="is",
                    name=item["name"],
                    account=account_map[
                        item["account_name"]
                    ],
                    posts_transaction=False,
                )

                category_id = resolve_category_id(
                    category_name_for(item)
                )

                if category_id is not None:
                    rule = schedule.rule

                    actions = read_json(
                        rule.actions
                    )

                    rule.actions = write_json(
                        rule.actions,
                        desired_actions(
                            actions,
                            category_id,
                        ),
                    )

            # ------------------------------------------
            # Commit
            # ------------------------------------------

            if (
                new_categories
                or changes
                or new_items
            ):
                actual.commit()

            print(
                f"SYNC FINISHED: "
                f"{len(new_categories)} categories created, "
                f"{len(new_items)} schedules created, "
                f"{len(changes)} schedules updated, "
                f"{len(skipped_items)} schedules skipped",
                flush=True,
            )

            print(
                "Automatic transaction posting: disabled",
                flush=True,
            )

            print(
                "Existing Actual categories: preserved",
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

    categoryGroup = lib.mkOption {
      type = lib.types.str;
      default = "Wallos Abonnementen";

      description =
        "Actual Budget category group used for "
        + "new categories imported from Wallos";
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

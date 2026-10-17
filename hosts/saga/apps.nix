
{ lib, ... }:

let
  enabledApps = [
    "actual-budget"
    "allos"
    "mazanoke"
    "pdf"
    "paperless"
    "dawarich"
    "wanderer"
    "filebrowser"
    "spoolman"
    "tasktrove"
    "karakeep"
    "mealie"
    "adventurelog"
    "immich"
    "manyfold"
    "lubelogger"
    "wallos"
  ];

  appModules =
    map (name: ../../modules/containers/${name}.nix) enabledApps;

in
{
  imports = appModules ++ [
    ../../modules/containers/actual-bunq-importer.nix
    ../../modules/containers/actual-wallos-importer.nix
  ];

  apps =
    (lib.genAttrs enabledApps (_: {
      enable = true;
      openFirewall = false;
    }))
    // {
      actual-bunq-importer = {
        enable = true;
        budgetName = "My Finances";
        actualPort = 5006;

        bunq = {
          enable = true;
          environment = "PRODUCTION";
          allowedIPv4 = "185.238.128.199";
          sinceDate = null;
          autoSync = true;
        };
      };

      actual-wallos-importer = {
        enable = true;
        wallosPort = 8282;
        autoSync = true;
      };
    };
}

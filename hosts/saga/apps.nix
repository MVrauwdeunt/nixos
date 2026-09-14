{ lib, ... }:

let
  enabledApps = [
    "mazanoke"
    "pdf"
    "paperless"
    "dawarich"
    "wanderer"
    "filebrowser"
    "spoolman"
  ];

  appModules =
    map (name: ../../modules/containers/${name}.nix) enabledApps;
in
{
  imports = appModules;

  apps =
    lib.genAttrs enabledApps (_: {
      enable = true;
      openFirewall = false;
    });
}
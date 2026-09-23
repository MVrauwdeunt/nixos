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
    "tasktrove"
    "karakeep"
    "mealie"
    "adventurelog"
    "immich"
    "manyfold"
  ];

  apps.manyfold = {
    enable = true;

    dataDir = "/var/lib/manyfold";
    libraryDir = "/mnt/Volume2/3d-models";

    port = 3214;
    openFirewall = false;

    tailscale.enable = true;

    sopsFile = ../../secrets.yaml;
  };

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
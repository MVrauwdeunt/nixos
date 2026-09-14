{ lib, ... }:

let
  enabledApps = [
    "mazanoke"
    "pdf"
    "paperless"
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
{ lib, ... }:

let
  enabledApps = [
    "beszel"
    "forgejo"
    "netalertx"
    "renovate"
    "unifi"
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
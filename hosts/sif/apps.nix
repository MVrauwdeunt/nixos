
{ lib, ... }:

let
  enabledApps = [
    "beszel"
    "forgejo"
    "netalertx"
    "renovate"
    "unifi"
    "n8n"
    "garmin-bridge"
    "homelable"
    "dependency-track"
  ];

  appModules =
    map (name: ../../modules/containers/${name}.nix) enabledApps;
in
{
  imports = appModules;

  apps =
    (lib.genAttrs enabledApps (_: {
      enable = true;
      openFirewall = false;
    }))
    // {
      homelable = {
        enable = true;
        openFirewall = false;

        mcp = {
          enable = true;
          port = 8001;
          listenAddress = "0.0.0.0";
          openFirewall = true;
        };
      };
    };
}

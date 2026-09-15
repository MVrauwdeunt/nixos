{ lib, ... }:

let
  enabledModules = [
    "hermes-agent"
    "signal-cli"
  ];

  enabledApps = [
    "open-webui"
  ];

  modules =
    map (name: ../../modules/${name}.nix) enabledModules;

  appModules =
    map (name: ../../modules/containers/${name}.nix) enabledApps;
in
{
  imports = modules ++ appModules;

  services.signalCli = {
    enable = true;
    httpPort = 8080;
  };

  apps = lib.genAttrs enabledApps (_: {
    enable = true;
    openFirewall = false;
  });
}
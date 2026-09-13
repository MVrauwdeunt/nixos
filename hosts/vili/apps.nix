{ lib, ... }:

let
  enabledModules = [
    "hermes-agent"
    "signal-cli"
  ];

  modules =
    map (name: ../../modules/${name}.nix) enabledModules;
in
{
  imports = modules;

  services.signalCli = {
    enable = true;
    httpPort = 8080;
  };
}
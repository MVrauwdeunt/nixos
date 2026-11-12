
{ lib, ... }:

let
  enabledModules = [
    "hermes-agent"
    "signal-cli"
  ];

  enabledApps = [
    "open-webui"
    "litellm"
    "honcho"
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

  # Publish the existing Hermes Webapp via Tailscale Services.
  my.tailscaleServices.local.hermes = {
    enable = true;
    serviceName = "hermes";
    port = 9120;
    systemdUnit = "hermes-agent.service";
  };

  apps = (lib.genAttrs enabledApps (_: {
    enable = true;
    openFirewall = false;
  })) // {
    open-webui = {
      enable = true;
      openFirewall = false;
      oidc.enable = true;
    };
  };
}

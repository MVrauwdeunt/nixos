{ config, lib, ... }:

with lib;

let
  cfg = config.apps.beszel-agent;
in
{
  options.apps.beszel-agent = {
    enable = mkEnableOption "Beszel agent";
  };

  config = mkIf cfg.enable {
    sops.secrets."beszel/agent" = {
      sopsFile = ../../secrets.yaml;
    };

    services.beszel.agent = {
      enable = true;
      environmentFile = config.sops.secrets."beszel/agent".path;
    };
  };
}

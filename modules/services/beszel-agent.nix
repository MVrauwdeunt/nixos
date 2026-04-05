{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.apps.beszel-agent;
in
{
  options.apps.beszel-agent = {
    enable = mkEnableOption "Beszel agent";

    envFile = mkOption {
      type = types.path;
      default = config.sops.secrets."beszel/agent".path;
      description = "Environment file containing KEY, TOKEN and HUB_URL";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.beszel-agent;
      description = "Beszel agent package";
    };
  };

  config = mkIf cfg.enable {
    sops.secrets."beszel/agent" = {
      sopsFile = ../../secrets.yaml;
    };

    systemd.services.beszel-agent = {
      description = "Beszel Agent";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        EnvironmentFile = cfg.envFile;
        ExecStart = "${cfg.package}/bin/beszel-agent";
        Restart = "always";
        RestartSec = "5s";
      };
    };
  };
}

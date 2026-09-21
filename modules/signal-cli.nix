{ config, lib, pkgs, ... }:

let
  cfg = config.services.signalCli;
  signalCliPkg = pkgs.signal-cli;
in
{
  options.services.signalCli = {
    enable = lib.mkEnableOption "signal-cli";

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/signal-cli";
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      signalCliPkg
    ];

    users.groups.signal-cli = {};

    users.users.signal-cli = {
      isSystemUser = true;
      group = "signal-cli";
      home = cfg.dataDir;
      createHome = true;
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 signal-cli signal-cli -"
    ];

    systemd.services.signal-cli = {
      description = "Signal CLI HTTP daemon";

      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        Type = "simple";
        User = "signal-cli";
        Group = "signal-cli";
        WorkingDirectory = cfg.dataDir;

        ExecStart = ''
          ${signalCliPkg}/bin/signal-cli \
            --config ${cfg.dataDir} \
            daemon \
            --http 127.0.0.1:${toString cfg.httpPort}
        '';

        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
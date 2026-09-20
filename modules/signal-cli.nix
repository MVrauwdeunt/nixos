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
  };
}
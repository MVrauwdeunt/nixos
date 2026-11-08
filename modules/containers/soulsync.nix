
{ config, lib, ... }:

let
  cfg = config.apps.soulsync;
in
{
  imports = [
    (import ./common.nix {
      name = "soulsync";

      # Official upstream stable image
      image = cfg.image;

      # SoulSync WebUI
      port = 8008;
      containerPort = 8008;
      bindAddress = "127.0.0.1";

      tailscaleDefault = true;

      # Persistent configuration
      configMount = "/app/config";
      createDataDir = true;

      # Upstream runtime settings
      useTimezone = true;
      usePuidPgid = true;
      bridgeNetwork = true;
      disableHealthcheck = false;

      environment = {
        PYTHONPATH = "/app";
        SOULSYNC_CONFIG_PATH = "/app/config/config.json";
        UMASK = "022";
      };

      extraVolumes = [
        # Application logs
        "${cfg.dataDir}/logs:/app/logs"

        # Persistent SQLite databases
        "soulsync_database:/app/data"

        # Shared Soulseek downloads
        "${cfg.downloadsDir}:/app/downloads"

        # Music library / transfer destination
        "${cfg.musicDir}:/app/Transfer"
      ];
    })
  ];

  options.apps.soulsync = {
    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/boulderbadgedad/soulsync:latest";
      description = "Official SoulSync stable container image.";
    };

    downloadsDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/shares/Downloads/Muziek/soularr";
      description = "Shared download directory used by slskd.";
    };

    musicDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/shares/Media/Muziek";
      description = "Music library and transfer destination.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.soulsync = {
      pull = lib.mkForce "always";

      labels.app = "soulsync";
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir}/logs 0755 1000 1000 -"
    ];
  };
}

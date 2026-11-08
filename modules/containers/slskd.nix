{ config, lib, ... }:

{
  imports = [
    (import ./common.nix {
      name = "slskd";
      image = "docker.io/slskd/slskd:0.26.2.0@sha256:d0963a3e5b16facd295bf4f2156dad0182f246b1b21a032cae12f5494c694843";
      port = 5030;
      tailscaleDefault = true;

      bindAddress = "0.0.0.0";
      configMount = "/app";
      usePuidPgid = false;
      bridgeNetwork = false;
      disableHealthcheck = false;
      directoryMode = "0775";
      directoryOwner = "zanbee";
      directoryGroup = "users";
      extraVolumes = [
        "${config.apps.slskd.downloadsDir}:/downloads"
        "${config.apps.slskd.mediaDir}:/music:ro"
      ];
      environment.SLSKD_REMOTE_CONFIGURATION = "true";
    })
  ];

  options.apps.slskd = {
    downloadsDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/shares/Downloads/Muziek/soularr";
    };
    mediaDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/shares/Media/Muziek";
    };
  };

  config = lib.mkIf config.apps.slskd.enable {
    systemd.tmpfiles.rules = [
      "d ${config.apps.slskd.downloadsDir} 0775 zanbee users -"
      "d ${config.apps.slskd.downloadsDir}/incomplete 0775 zanbee users -"
      "d ${config.apps.slskd.downloadsDir}/complete 0775 zanbee users -"
    ];
  };
}

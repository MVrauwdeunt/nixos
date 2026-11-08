
{ config, lib, ... }:

let
  cfg = config.apps.lubelogger;
in
{
  imports = [
    (import ./common.nix {
      name = "lubelogger";

      image = "docker.io/hargata/lubelogger:v1.7.4@sha256:483a9d7582c4e6258615fd822b3de4193b4fcc4230d0a92432c6d407faf75af2";

      port = 8082;
      containerPort = 8080;
      bindAddress = "127.0.0.1";

      tailscaleDefault = true;

      mountConfig = false;

      directoryOwner = "root";
      directoryGroup = "root";

      usePuidPgid = false;
      disableHealthcheck = false;

      extraVolumes = [
        "${config.apps.lubelogger.dataDir}/data:/App/data"
        "${config.apps.lubelogger.dataDir}/keys:/root/.aspnet/DataProtection-Keys"
      ];

      extraOptions = [
        "--security-opt=no-new-privileges"
      ];
    })
  ];

  options.apps.lubelogger.image = lib.mkOption {
    type = lib.types.str;
    default = "docker.io/hargata/lubelogger:v1.7.4@sha256:483a9d7582c4e6258615fd822b3de4193b4fcc4230d0a92432c6d407faf75af2";
    description = "LubeLogger container image.";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";

    virtualisation.oci-containers.containers.lubelogger.image =
      lib.mkForce cfg.image;

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir}/data 0755 root root -"
      "d ${cfg.dataDir}/keys 0700 root root -"
    ];

    systemd.services.podman-lubelogger = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
    };
  };
}

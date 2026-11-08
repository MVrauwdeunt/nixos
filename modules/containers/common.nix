
{
  name,
  image,
  port,
  containerPort ? port,
  bindAddress ? "127.0.0.1",
  publishedPorts ? null,
  networks ? [ ],
  dataDir ? "/var/lib/${name}",
  configMount ? "/config",
  mountConfig ? true,
  createDataDir ? true,
  extraVolumes ? [ ],
  environment ? { },
  useTimezone ? true,
  extraOptions ? [ ],
  directoryMode ? "0755",
  directoryOwner ? "1000",
  directoryGroup ? "1000",
  usePuidPgid ? true,
  bridgeNetwork ? true,
  disableHealthcheck ? true,
  tailscaleDefault ? false,
}:

{ config, lib, ... }:

let
  cfg = config.apps.${name};

  networkUnits =
    map (network: "podman-network-${network}.service") networks;

  sharedEnvironment =
    lib.optionalAttrs useTimezone {
      TZ = config.time.timeZone;
    }
    // lib.optionalAttrs usePuidPgid {
      PUID = "1000";
      PGID = "1000";
    };
in
{
  options.apps.${name} = {
    enable = lib.mkEnableOption "${name} container";

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = tailscaleDefault;
      description = "Expose ${name} through Tailscale Serve.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = dataDir;
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = port;
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.${name} = {
      inherit image networks;

      pull = "missing";

      environment = sharedEnvironment // environment;

      ports =
        if publishedPorts != null then
          publishedPorts
        else
          [
            "${bindAddress}:${toString cfg.port}:${toString containerPort}"
          ];

      volumes =
        lib.optionals mountConfig [
          "${cfg.dataDir}:${configMount}"
        ]
        ++ extraVolumes;

      extraOptions =
        lib.optionals (networks == [ ] && bridgeNetwork) [
          "--network=bridge"
        ]
        ++ lib.optional disableHealthcheck "--health-cmd=none"
        ++ extraOptions;
    };

    systemd.services."podman-${name}" =
      lib.mkIf (networks != [ ]) {
        requires = networkUnits;
        after = networkUnits;
      };

    systemd.tmpfiles.rules =
      lib.optionals createDataDir [
        "d ${cfg.dataDir} ${directoryMode} ${directoryOwner} ${directoryGroup} -"
      ];

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}

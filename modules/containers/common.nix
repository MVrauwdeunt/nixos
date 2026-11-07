
{
  name,
  image,
  port,
  containerPort ? port,
  bindAddress ? "127.0.0.1",
  networks ? [ ],
  dataDir ? "/var/lib/${name}",
  configMount ? "/config",
  extraVolumes ? [ ],
  environment ? { },
  extraOptions ? [ ],
  directoryMode ? "0755",
  directoryOwner ? "root",
  directoryGroup ? "root",
  tailscaleDefault ? false,
}:

{ config, lib, ... }:

let
  cfg = config.apps.${name};

  networkUnits =
    map (network: "podman-network-${network}.service") networks;
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
      inherit image environment;

      pull = "missing";

      networks = networks;

      ports = [
        "${bindAddress}:${toString cfg.port}:${toString containerPort}"
      ];

      volumes = [
        "${cfg.dataDir}:${configMount}"
      ] ++ extraVolumes;

      extraOptions =
        extraOptions;
    };

    systemd.services."podman-${name}" =
      lib.mkIf (networks != [ ]) {
        requires = networkUnits;
        after = networkUnits;
      };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} ${directoryMode} ${directoryOwner} ${directoryGroup} -"
    ];

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}

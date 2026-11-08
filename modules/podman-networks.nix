
{ config, lib, pkgs, ... }:

let
  aiNetwork = "ai-backend";
  aiUnit = "podman-network-${aiNetwork}";

  networks = lib.filterAttrs
    (_: enabled: enabled)
    config.infrastructure.podman.networks;

  networkServices = lib.mapAttrs' (
    name: _:
    lib.nameValuePair "podman-network-${name}" {
      description = "Create Podman network ${name}";

      wantedBy = [ "multi-user.target" ];

      path = [ pkgs.podman ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        if ! podman network exists ${name}; then
          podman network create \
            --driver bridge \
            ${name}
        fi
      '';
    }
  ) networks;
in
{
  options.infrastructure.podman = {
    networks = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = { };
      description = "Managed Podman bridge networks";
    };

    aiBackend.enable =
      lib.mkEnableOption "Shared Podman network for AI services";
  };

  config = lib.mkMerge [
    {
      virtualisation.podman.enable =
        lib.mkIf (networks != { }) true;

      systemd.services = networkServices;
    }

    (lib.mkIf config.infrastructure.podman.aiBackend.enable {
      virtualisation.podman.enable = true;

      systemd.services.${aiUnit} = {
        description = "Create Podman AI backend network";

        wantedBy = [ "multi-user.target" ];

        path = [ pkgs.podman ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        script = ''
          if ! podman network exists ${aiNetwork}; then
            podman network create \
              --driver bridge \
              ${aiNetwork}
          fi
        '';
      };

      networking.firewall.interfaces."podman1".allowedTCPPorts = [ 8642 ];

      systemd.services.podman-litellm = {
        requires = [ "${aiUnit}.service" ];
        after = [ "${aiUnit}.service" ];
      };

      systemd.services.podman-open-webui = {
        requires = [ "${aiUnit}.service" ];
        after = [ "${aiUnit}.service" ];
      };
    })
  ];
}

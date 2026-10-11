# modules/podman-networks.nix
{ config, lib, pkgs, ... }:

let
  networkName = "ai-backend";
  unitName = "podman-network-${networkName}";
in
{
  options.infrastructure.podman.aiBackend.enable =
    lib.mkEnableOption "Shared Podman network for AI services";

  config = lib.mkIf config.infrastructure.podman.aiBackend.enable {
    virtualisation.podman.enable = true;

    systemd.services.${unitName} = {
      description = "Create Podman AI backend network";

      wantedBy = [ "multi-user.target" ];

      path = [ pkgs.podman ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        if ! podman network exists ${networkName}; then
          podman network create \
            --driver bridge \
            ${networkName}
        fi
      '';
    };
    networking.firewall.interfaces."podman1".allowedTCPPorts = [ 8642 ];
    
    systemd.services.podman-litellm = {
      requires = [ "${unitName}.service" ];
      after = [ "${unitName}.service" ];
    };

    systemd.services.podman-open-webui = {
      requires = [ "${unitName}.service" ];
      after = [ "${unitName}.service" ];
    };
  };
}
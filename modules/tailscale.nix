# modules/tailscale.nix
{ config, lib, ... }:
{
  services.tailscale = {
    enable = lib.mkDefault true;
    authKeyFile = config.sops.secrets.tailscaleAuthKey.path;
    extraUpFlags = lib.mkDefault [
      "--advertise-exit-node"
      "--advertise-tags=tag:nixos"
      "--ssh"
    ];
    useRoutingFeatures = lib.mkDefault "server";
  };

  # Poort voor TS
  networking.firewall.allowedUDPPorts = lib.mkDefault [ 41641 ];
}

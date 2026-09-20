# modules/tailscale.nix
{ config, lib, ... }:

{
  services.tailscale = {
    enable = lib.mkDefault true;
    authKeyFile = config.sops.secrets.tailscaleAuthKey.path;

    extraUpFlags = lib.mkDefault [
      "--advertise-exit-node"
      "--ssh"
    ];

    useRoutingFeatures = lib.mkDefault "server";
  };

  # Keep Tailscale running during NixOS switches so remote
  # deployments over the tailnet do not terminate themselves.
  systemd.services.tailscaled.restartIfChanged = false;

  # Allow direct Tailscale UDP traffic.
  networking.firewall.allowedUDPPorts = lib.mkDefault [ 41641 ];
}
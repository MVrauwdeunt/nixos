
{ config, lib, ... }:

{
  services.tailscale = {
    enable = true;

    authKeyFile = config.sops.secrets.tailscaleAuthKey.path;

    openFirewall = false;
    useRoutingFeatures = "none";

    extraUpFlags = [
      "--advertise-tags=tag:ci-runner"
      "--accept-routes=false"
      "--accept-dns=true"
      "--ssh=false"
      "--shields-up"
    ];
  };

  # Trust local loopback traffic only.
  networking.firewall.trustedInterfaces = lib.mkForce [ "lo" ];

  systemd.services.tailscaled.restartIfChanged = false;
}

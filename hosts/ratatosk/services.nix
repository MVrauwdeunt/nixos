# hosts/ratatosk/services.nix

{ lib, ... }:

{
  apps.beszel-agent.enable = true;

  services.tailscale.extraUpFlags = lib.mkForce [
    "--advertise-tags=tag:nixos"
    "--ssh"
  ];

  services.tailscale.useRoutingFeatures =
    lib.mkForce "client";
}
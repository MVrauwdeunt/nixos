# hosts/ratatosk/network.nix

{ lib, ... }:

{
  # Hetzner Rescue gebruikt eth0, maar NixOS hernoemt
  # de virtio interface tijdens boot naar enp1s0.
  systemd.network.networks."10-wan".matchConfig.Name =
    lib.mkForce "enp1s0";

  networking.firewall.allowedTCPPorts = [
    22
    80
  ];
}
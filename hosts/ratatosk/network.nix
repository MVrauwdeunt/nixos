# hosts/ratatosk/network.nix

{ lib, ... }:

{
  # Hetzner Rescue gebruikt eth0, NixOS ziet de virtio-interface als enp0s3.
  systemd.network.networks."10-wan" = {
    matchConfig.Name = lib.mkForce "enp0s3";

    address = [
      "2a01:4f8:c2c:f65c::1/64"
    ];

    routes = [
      {
        Gateway = "fe80::1";
      }
    ];
  };

  networking.firewall.allowedTCPPorts = [
    22
    80
    443
  ];
}
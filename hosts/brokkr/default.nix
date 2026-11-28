
{ lib, ... }:

{
  imports = [
    ../../modules/users/zanbee
    ./sops.nix
    ./tailscale.nix
    ./podman.nix
    ./forgejo-runner.nix
  ];

  # Allow the administrator to deploy locally built store paths.
  nix.settings = {
    trusted-users = lib.mkForce [ "root" "zanbee" ];
    require-sigs = true;
  };

  # IPv4-only networking.
  networking.enableIPv6 = false;

  systemd.network.networks."10-lan".networkConfig = {
    DHCP = lib.mkForce "ipv4";
    IPv6AcceptRA = lib.mkForce false;
  };

  # Restrict SSH to the administrator workstation.
  services.openssh.openFirewall = false;

  networking.nftables.enable = true;

  networking.firewall.extraInputRules = ''
    ip saddr 192.168.178.20 tcp dport 22 accept
  '';

  system.stateVersion = lib.mkForce "26.05";
}

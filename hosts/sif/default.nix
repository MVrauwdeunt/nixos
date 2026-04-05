{ config, modulesPath, pkgs, lib, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../../modules/users/zanbee
  ];

  ./modules/users

  nix.settings.sandbox = false;

  proxmoxLXC = {
    manageNetwork = false;
    manageHostName = false;
    privileged = true;
  };

  # Network config for Proxmox LXC (eth0 via DHCP)
  networking.useDHCP = lib.mkForce false;
  networking.useNetworkd = lib.mkForce true;

  systemd.network.enable = true;
  systemd.network.networks."10-eth0" = {
    matchConfig.Name = "eth0";
    networkConfig = {
      DHCP = "yes";
      IPv6AcceptRA = true;
    };
  };

  # Not useful in containers
  services.fstrim.enable = lib.mkForce false;
  services.qemuGuest.enable = lib.mkForce false;

  # --------------------------------------------------
  # TEMPORARY SSH BOOTSTRAP CONFIG
  # Remove this after SSH key login works
  # --------------------------------------------------
  services.openssh.enable = true;
  services.openssh.openFirewall = true;
  services.openssh.settings = {
    PermitRootLogin = lib.mkForce "yes";
    PasswordAuthentication = lib.mkForce true;
    PermitEmptyPasswords = lib.mkForce true;
  };

  # DNS caching (optional)
  services.resolved = {
    extraConfig = ''
      Cache=true
      CacheFromLocalhost=true
    '';
  };

  # --------------------------------------------------
  # TEMPORARY: disable secrets during bootstrap
  # --------------------------------------------------
  services.tailscale.enable = lib.mkForce false;
  sops.defaultSopsFile = lib.mkForce null;
  sops.secrets = lib.mkForce {};

  # Match your initial container version
  system.stateVersion = lib.mkForce "25.11";

  systemd.suppressedSystemUnits = [
    "sys-kernel-debug.mount"
];

}

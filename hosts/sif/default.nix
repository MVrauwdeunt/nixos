{ config, modulesPath, pkgs, lib, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
  ];

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

  # Enable SSH for initial access
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
      PermitEmptyPasswords = "yes";
    };
  };

  # DNS caching (optional but harmless)
  services.resolved = {
    extraConfig = ''
      Cache=true
      CacheFromLocalhost=true
    '';
  };

  # Temporary: disable secrets & dependent services for bootstrap
  services.tailscale.enable = lib.mkForce false;
  sops.defaultSopsFile = lib.mkForce null;
  sops.secrets = lib.mkForce {};

  system.stateVersion = "25.11";
}

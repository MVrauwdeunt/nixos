{ lib, ... }:
{
  nix.settings.sandbox = false;
  nix.settings.trusted-users = [ "root" "zanbee" ];

  proxmoxLXC = {
    manageNetwork = false;
    manageHostName = false;
    privileged = true;
  };

  # Not useful in containers
  services.fstrim.enable = lib.mkForce false;
  services.qemuGuest.enable = lib.mkForce false;

  # --------------------------------------------------
  # TEMPORARY SSH BOOTSTRAP CONFIG
  # --------------------------------------------------
  services.openssh.enable = true;
  services.openssh.openFirewall = true;
  services.openssh.settings = {
    PermitRootLogin = lib.mkForce "yes";
    PasswordAuthentication = lib.mkForce true;
    PermitEmptyPasswords = lib.mkForce true;
  };

  # DNS caching
  services.resolved.extraConfig = ''
    Cache=true
    CacheFromLocalhost=true
  '';

  # --------------------------------------------------
  # System
  # --------------------------------------------------
  system.stateVersion = lib.mkForce "25.11";

  systemd.suppressedSystemUnits = [
    "sys-kernel-debug.mount"
  ];
}

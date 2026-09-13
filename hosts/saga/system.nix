{ lib, ... }:
{
  nix.settings.sandbox = false;
  nix.settings.trusted-users = [ "root" "zanbee" ];

  proxmoxLXC = {
    manageNetwork = false;
    manageHostName = true;
    privileged = false;
  };

  services.fstrim.enable = lib.mkForce false;
  services.qemuGuest.enable = lib.mkForce false;
  systemd.oomd.enable = false;

  services.resolved.settings = {
    Resolve = {
      Cache = true;
      CacheFromLocalhost = true;
    };
  };

  system.stateVersion = lib.mkForce "25.11";

  systemd.suppressedSystemUnits = [
    "sys-kernel-debug.mount"
  ];
}
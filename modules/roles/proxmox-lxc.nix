
{ lib, ... }:
{
  nix.settings.sandbox = false;
  nix.settings.trusted-users = [ "root" "zanbee" ];

  proxmoxLXC = {
    manageNetwork = false;
    manageHostName = true;
    privileged = false;
  };

  # Services not applicable inside Proxmox LXC.
  services.fstrim.enable = lib.mkForce false;
  services.qemuGuest.enable = lib.mkForce false;
  systemd.oomd.enable = false;

  # DNS caching.
  services.resolved.settings.Resolve = {
    Cache = true;
    CacheFromLocalhost = true;
  };

  systemd.suppressedSystemUnits = [
    "sys-kernel-debug.mount"
  ];
}


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

  # DNS resolver with split DNS for Tailscale.
  # Also listen on the Podman gateway for Wallos.
  services.resolved.settings = {
    Resolve = {
      Cache = true;
      CacheFromLocalhost = true;
      DNSStubListenerExtra = "10.88.0.1";
    };
  };

  system.stateVersion = lib.mkForce "25.11";

  systemd.suppressedSystemUnits = [
    "sys-kernel-debug.mount"
  ];
}


{ lib, ... }:
{

  # Split DNS for Tailscale; also listen on the Podman gateway for Wallos.
  services.resolved.settings.Resolve.DNSStubListenerExtra = "10.88.0.1";

  system.stateVersion = lib.mkForce "25.11";
}

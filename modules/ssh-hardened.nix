{ ... }:
{
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PermitRootLogin = "no";
    X11Forwarding = false;
  };
  security.sudo.wheelNeedsPassword = false;
}

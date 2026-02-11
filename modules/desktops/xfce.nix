{ config, pkgs, ... }:

{
  services.xserver.enable = true;

  # Display manager (login screen)
  services.xserver.displayManager.lightdm.enable = true;

  # XFCE desktop
  services.xserver.desktopManager.xfce.enable = true;

  # Keyboard layout
  services.xserver.xkb.layout = "us";

  # VM quality-of-life (SPICE clipboard, resize, etc.)
  services.spice-vdagentd.enable = true;

  systemd.defaultUnit = "graphical.target";
}

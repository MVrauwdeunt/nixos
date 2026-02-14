{ ... }:
{
  services.xserver.enable = true;

  # Display manager (login screen)
  services.displayManager.sddm.enable = true;

  # KDE Plasma desktop
  services.desktopManager.plasma6.enable = true;
}


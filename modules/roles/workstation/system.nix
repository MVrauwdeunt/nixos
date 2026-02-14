{ pkgs, ... }:
{
  # Use bash as login shell for zanbee (workstation role)
  my.users.zanbee.shell = pkgs.bashInteractive;

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;

  hardware.pulseaudio.enable = false;

  services.printing.enable = true;

  programs.nm-applet.enable = true;
}


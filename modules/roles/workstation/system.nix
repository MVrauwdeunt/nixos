{ pkgs, ... }:
{
  programs.zsh.enable = true;

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  sound.enable = true;
  hardware.pulseaudio.enable = false;

  services.printing.enable = true;

  programs.nm-applet.enable = true;

}


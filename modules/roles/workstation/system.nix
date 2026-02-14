{ pkgs, ... }:
{
  programs.zsh.enable = true;

  # Zet login shell van zanbee op zsh
  users.users.zanbee.shell = pkgs.zsh;

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  sound.enable = true;
  hardware.pulseaudio.enable = false;

  services.printing.enable = true;

  programs.nm-applet.enable = true;

}


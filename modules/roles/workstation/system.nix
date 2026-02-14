{ pkgs, ... }:
{
  programs.zsh.enable = true;

  # Zet login shell van zanbee op zsh
  my.users.zanbee.shell = pkgs.zsh;

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


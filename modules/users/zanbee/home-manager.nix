{ pkgs, ... }:

{
  home.username = "zanbee";
  home.homeDirectory = "/home/zanbee";
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  programs.bash.enable = true;

  programs.starship.enable = true;
  programs.kitty.enable = true;

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
  };

  home.packages = with pkgs; [
    ripgrep
    fd
    jq
    ulauncher
  ];
}


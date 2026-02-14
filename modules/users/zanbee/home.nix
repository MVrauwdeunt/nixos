{ pkgs, ... }:
{
  home.username = "zanbee";
  home.homeDirectory = "/home/zanbee";

  # Belangrijk: zet dit op jouw HM/NixOS release en laat het daarna met rust.
  home.stateVersion = "25.05";

  programs.git.enable = true;

  home.packages = with pkgs; [
    ripgrep
    fd
  ];
}


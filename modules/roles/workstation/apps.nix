{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    pkgs.kdePackages.kate
    pkgs.kdePackages.kdenlive
    firefox
  ];
}


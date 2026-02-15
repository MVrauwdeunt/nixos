# modules/packages.nix
{ pkgs, ... }:
{
  # Alles in deze lijst komt op ALLE hosts
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    tree
    dig
    fzf
    bat
    jq
    just

    # Handig (optioneel, zet ze aan naar smaak):
    # wget unzip zip
    # htop tmux jq ripgrep fd tree
    # dig  # via bind
    # mtr nmap iperf3
    # eza bat fzf
  ];

  # (optioneel) quality of life
  programs.bash.completion.enable = true;
  environment.variables.EDITOR = "vim";
}

{ ... }:
{
  # Workstation-only bash QoL (interactive)
  programs.bash.interactiveShellInit = ''
    # Small typo fixes for cd (workstation only)
    shopt -s cdspell

    # Extended pattern matching (handy, but keep it workstation)
    shopt -s extglob
  '';

  # fzf integration
  programs.fzf = {
    keybindings = true;
    fuzzyCompletion = true;
  };
}



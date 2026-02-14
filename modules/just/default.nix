{ pkgs, ... }:

let
  # Base Justfile shipped to every host
  baseJustfile = ./base.just;

  # Bash snippet to auto-generate aliases from recipes in ~/.justfile
  bashAliasScript = pkgs.writeText "just-aliases.sh" ''
    # Auto-generate bash aliases from recipes in ~/.justfile
    # Only run in interactive shells
    case "$-" in
      *i*) ;;
      *) return ;;
    esac

    # Ensure just and ~/.justfile exist
    command -v just >/dev/null 2>&1 || return
    [ -f "$HOME/.justfile" ] || return

    # Generate aliases safely
    while IFS= read -r recipe; do
      # Skip empty lines
      [ -n "$recipe" ] || continue

      # Skip invalid alias names
      case "$recipe" in
        *[!a-zA-Z0-9_-]*)
          continue
          ;;
      esac

      alias "$recipe"="just -f \"$HOME/.justfile\" $recipe"
    done < <(just -f "$HOME/.justfile" --summary 2>/dev/null)
  '';
in
{
  ########################################
  # Install just binary
  ########################################
  environment.systemPackages = [
    pkgs.just
  ];

  ########################################
  # Install global base Justfile
  ########################################
  environment.etc."just/Justfile".source = baseJustfile;

  ########################################
  # Install alias generator script
  ########################################
  environment.etc."just/just-aliases.sh".source = bashAliasScript;

  ########################################
  # Ensure bash runs the alias generator for every interactive shell
  ########################################
  programs.bash.interactiveShellInit = ''
    # Load global just aliases for interactive shells
    if [ -r /etc/just/just-aliases.sh ]; then
      . /etc/just/just-aliases.sh
    fi
  '';

  ########################################
  # Symlink only ~/.justfile into user homes (non-root)
  ########################################
  system.activationScripts.linkGlobalJustfile.text = ''
    for home in /home/*; do
      [ -d "$home" ] || continue

      user="$(basename "$home")"

      if [ ! -e "$home/.justfile" ]; then
        ln -s /etc/just/Justfile "$home/.justfile"
        chown -h "$user:$user" "$home/.justfile" || true
      fi
    done
  '';
}


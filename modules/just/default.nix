{ pkgs, ... }:

let
  # Base Justfile shipped to every host
  baseJustfile = ./base.just;
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
  # Symlink ~/.justfile into user homes (non-root)
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

  ########################################
  # Generate recipe aliases in interactive bash shells
  ########################################
  programs.bash.interactiveShellInit = ''
    # Auto-generate bash aliases from recipes in ~/.justfile
    # Only run in interactive shells
    case "$-" in
      *i*) ;;
      *) return ;;
    esac

    # Prevent running twice
    if [ -n "''${__JUST_ALIASES_LOADED:-}" ]; then
      return
    fi
    __JUST_ALIASES_LOADED=1

    command -v just >/dev/null 2>&1 || return
    [ -f "$HOME/.justfile" ] || return

    # Generate aliases using simple command substitution
    for recipe in $(just -f "$HOME/.justfile" --summary 2>/dev/null); do
      case "$recipe" in
        *[!a-zA-Z0-9_-]*)
          continue
          ;;
      esac
      alias "$recipe"="just -f \"$HOME/.justfile\" $recipe"
    done
  '';
}


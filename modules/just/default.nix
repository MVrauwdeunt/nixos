{ pkgs, ... }:

let
  # Base Justfile shipped to every host
  baseJustfile = ./base.just;
in
{
  # Install just
  environment.systemPackages = [ pkgs.just ];

  # Ship the base Justfile
  environment.etc."just/Justfile".source = baseJustfile;

  # Create ~/.justfile symlink for users under /home (non-root)
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

  # Generate recipe aliases for interactive shells (bash-focused)
  environment.shellInit = ''
    # Auto-generate shell aliases from recipes in ~/.justfile (interactive shells only)
    case "$-" in
      *i*) ;;
      *) return ;;
    esac

    command -v just >/dev/null 2>&1 || return
    [ -f "$HOME/.justfile" ] || return

    while IFS= read -r recipe; do
      [ -n "$recipe" ] || continue
      case "$recipe" in
        *[!a-zA-Z0-9_-]*)
          continue
          ;;
      esac
      alias "$recipe"="just -f \"$HOME/.justfile\" $recipe"
    done < <(just -f "$HOME/.justfile" --summary 2>/dev/null)
  '';
}


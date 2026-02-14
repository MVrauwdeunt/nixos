{ pkgs, ... }:

let
  # Base Justfile shipped to every host
  baseJustfile = ./base.just;

  # Bash snippet to auto-generate aliases from recipes in ~/.justfile
  bashAliases = pkgs.writeText "just-aliases.sh" ''
    # Auto-generate bash aliases from recipes in ~/.justfile
    # Only run in interactive shells
    case "$-" in
      *i*) ;;
      *) return ;;
    esac

    # Only proceed if just and ~/.justfile exist
    command -v just >/dev/null 2>&1 || return
    [ -f "$HOME/.justfile" ] || return

    # Generate aliases for recipes
    while IFS= read -r recipe; do
      case "$recipe" in
        ''|*[!a-zA-Z0-9_-]*)
          continue
          ;;
      esac
      alias "$recipe"="just -f \"$HOME/.justfile\" -d. $recipe"
    done < <(just -f "$HOME/.justfile" --summary 2>/dev/null)
  '';
in
{
  environment.systemPackages = [
    pkgs.just
  ];

  environment.etc."just/Justfile".source = baseJustfile;
  environment.etc."profile.d/just-aliases.sh".source = bashAliases;

  system.activationScripts.linkGlobalJustfiles.text = ''
    for home in /home/*; do
      [ -d "$home" ] || continue

      user="$(basename "$home")"

      if [ ! -e "$home/Justfile" ]; then
        ln -s /etc/just/Justfile "$home/Justfile"
        chown -h "$user:$user" "$home/Justfile" || true
      fi

      if [ ! -e "$home/.justfile" ]; then
        ln -s /etc/just/Justfile "$home/.justfile"
        chown -h "$user:$user" "$home/.justfile" || true
      fi
    done
  '';
}


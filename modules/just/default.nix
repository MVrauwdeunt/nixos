{ pkgs, ... }:

let
  # Base Justfile shipped to every host
  baseJustfile = ./base.just;

  # Bash snippet to auto-generate aliases from recipes in ~/.justfile
  bashAliasScript = ''
    # Auto-generate bash aliases from recipes in ~/.justfile
    # Only run in interactive shells
    case "$-" in
      *i*) ;;
      *) return ;;
    esac

    # Prevent running twice in the same shell
    if [ -n "''${__JUST_ALIASES_LOADED:-}" ]; then
      return
    fi
    __JUST_ALIASES_LOADED=1

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

  # Run the alias generator in interactive bash shells
  programs.bash.interactiveShellInit = bashAliasScript;

  # Also source it for login shells (some setups rely on /etc/profile.d)
  environment.etc."profile.d/just-aliases.sh".text = bashAliasScript;
}


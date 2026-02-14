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

    # Ensure just and ~/.justfile exist
    command -v just >/dev/null 2>&1 || return
    [ -f "$HOME/.justfile" ] || return

    # Generate aliases safely
    while IFS= read -r recipe; do
      # Skip empty lines
      if [ -z "$recipe" ]; then
        continue
      fi

      # Skip invalid alias names
      case "$recipe" in
        *[!a-zA-Z0-9_-]*)
          continue
          ;;
      esac

      alias "$recipe"="just -f \"$HOME/.justfile\" -d. $recipe"
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
  # Load alias generator for bash users
  ########################################
  environment.etc."profile.d/just-aliases.sh".source = bashAliases;

  ########################################
  # Symlink Justfiles into user homes
  ########################################
  system.activationScripts.linkGlobalJustfiles.text = ''
    for home in /home/*; do
      [ -d "$home" ] || continue

      user="$(basename "$home")"

      # ~/Justfile for default just lookup
      if [ ! -e "$home/Justfile" ]; then
        ln -s /etc/just/Justfile "$home/Justfile"
        chown -h "$user:$user" "$home/Justfile" || true
      fi

      # ~/.justfile for alias generation
      if [ ! -e "$home/.justfile" ]; then
        ln -s /etc/just/Justfile "$home/.justfile"
        chown -h "$user:$user" "$home/.justfile" || true
      fi
    done
  '';
}


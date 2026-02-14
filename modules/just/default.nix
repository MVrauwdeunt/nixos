{ pkgs, ... }:

let
  # Base Justfile shipped to every host
  baseJustfile = ./base.just;
in
{
  # Install just normally
  environment.systemPackages = [
    pkgs.just
  ];

  # Install the global base Justfile
  environment.etc."just/Justfile".source = baseJustfile;

  # Create ~/Justfile symlink for each real user under /home
  system.activationScripts.linkGlobalJustfile.text = ''
    for home in /home/*; do
      [ -d "$home" ] || continue

      user="$(basename "$home")"

      # Skip if Justfile already exists
      if [ ! -e "$home/Justfile" ]; then
        ln -s /etc/just/Justfile "$home/Justfile"
        chown -h "$user:$user" "$home/Justfile" || true
      fi
    done
  '';
}


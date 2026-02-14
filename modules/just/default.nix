{ pkgs, lib, ... }:

let
  # Base Justfile stored in the repo (adjust this path if you prefer another location)
  baseJustfile = ./base.just;

  # Wrapper that uses a project Justfile if found, otherwise falls back to /etc/just/Justfile
  justWrapper = pkgs.writeShellScriptBin "just" ''
    set -euo pipefail

    # Walk upwards to find a project Justfile/justfile
    search_dir="$PWD"
    while [ "$search_dir" != "/" ]; do
      if [ -f "$search_dir/Justfile" ] || [ -f "$search_dir/justfile" ]; then
        exec ${pkgs.just}/bin/just "$@"
      fi
      search_dir="$(dirname "$search_dir")"
    done

    # No project Justfile found: use the global base Justfile
    exec ${pkgs.just}/bin/just --justfile /etc/just/Justfile "$@"
  '';
in
{
  # Install just and the wrapper (wrapper will be earlier in PATH)
  environment.systemPackages = [
    pkgs.just
    justWrapper
  ];

  # Install the global base Justfile on every host
  environment.etc."just/Justfile".source = baseJustfile;
}


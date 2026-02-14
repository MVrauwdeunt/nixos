{ pkgs, lib, ... }:

let
  # Base Justfile shipped to every host
  baseJustfile = ./base.just;

  # Wrapper that prefers a project Justfile, otherwise uses the global one
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
  # Force the wrapper to be installed (and avoid installing the real `just` into PATH)
  environment.systemPackages = lib.mkForce [
    justWrapper
  ];

  # Install the global base Justfile
  environment.etc."just/Justfile".source = baseJustfile;
}


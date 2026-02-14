{ pkgs, ... }:

let
  # Base Justfile shipped to every host
  baseJustfile = ./base.just;

  # Wrapper that prefers a project Justfile, otherwise uses the global one
  justWrapper = pkgs.writeShellScriptBin "just" ''
    set -euo pipefail

    # Try default justfile discovery (works without coreutils).
    # If a project Justfile exists somewhere above, this succeeds.
    if ${pkgs.just}/bin/just --unstable --dump >/dev/null 2>&1; then
      exec ${pkgs.just}/bin/just "$@"
    fi

    # No project Justfile found: use the global base Justfile
    exec ${pkgs.just}/bin/just --justfile /etc/just/Justfile "$@"
  '';
in
{
  # Install the wrapper (and also the real just binary for completeness)
  environment.systemPackages = [
    pkgs.just
    justWrapper
  ];

  # Install the global base Justfile
  environment.etc."just/Justfile".source = baseJustfile;
}


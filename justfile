# Repo-wide NixOS management. Does not replace /etc/just/Justfile.
set shell := ["bash", "-euo", "pipefail", "-c"]

hosts := "bifrost sif mimir vili saga ratatosk vm proxmox-vm"

default:
  @just --list

# Show available host configurations
hosts:
  @echo "{{hosts}}" | tr ' ' '\n'

# Evaluate flake and deploy-rs checks without building configurations
check:
  nix flake check --no-build --show-trace

# Confirm a named NixOS host configuration evaluates
eval HOST:
  nix eval --raw '.#nixosConfigurations.{{HOST}}.config.networking.hostName'

# Build configuration, without activating it (requires appropriate builder)
build HOST:
  nix build '.#nixosConfigurations.{{HOST}}.config.system.build.toplevel' --out-link 'result-{{HOST}}'

# Check formatting of tracked Nix files, using nixfmt from nixpkgs
fmt-check:
  @git ls-files -z '*.nix' | xargs -0 -r nixfmt --check

# Format tracked Nix files (review git diff afterwards)
fmt:
  @git ls-files -z '*.nix' | xargs -0 -r nixfmt

# CI validation: evaluation plus flake checks; no deployment
ci-check:
  just check

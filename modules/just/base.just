# Global base Justfile (/etc/just/Justfile)
# Goal: useful on any host, without requiring the repo to be present.

set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# List available recipes by default
default:
  @just --list

# Show basic system info
info:
  hostnamectl
  echo
  nixos-version
  echo
  uname -a

# Quick overview: disk, memory, load, top processes
status:
  uptime
  echo
  df -h
  echo
  free -h || true
  echo
  ps aux --sort=-%cpu | head -n 15

# Show networking basics
net:
  ip -brief addr
  echo
  ip route
  echo
  resolvectl status || true

# Show last boot logs (useful when something fails after reboot)
bootlog lines=200:
  journalctl -b -n {{lines}} --no-pager

# Follow logs (optionally filter by service name)
logs service="":
  if [ -n "{{service}}" ]; then \
    journalctl -fu "{{service}}" --no-pager; \
  else \
    journalctl -f --no-pager; \
  fi

# Restart a systemd service
restart service:
  sudo systemctl restart "{{service}}"
  sudo systemctl status "{{service}}" --no-pager

# Show systemd service status
svc service:
  systemctl status "{{service}}" --no-pager

# List failed units
failed:
  systemctl --failed --no-pager

# Show Nix store/GC info (safe read-only)
nix-info:
  nix --version
  echo
  nix store info --store /nix || true
  echo
  nix path-info -S /run/current-system || true

# Garbage collect old generations (safe-ish, but still an action)
# Keep it explicit so you don't run it accidentally.
gc:
  sudo nix-collect-garbage -d

# Rebuild from local /etc/nixos if present (common on servers)
# This will NOT work if you only use flakes elsewhere, but it's a good fallback.
rebuild:
  if [ -e /etc/nixos/configuration.nix ] || [ -e /etc/nixos/flake.nix ]; then \
    sudo nixos-rebuild switch; \
  else \
    echo "/etc/nixos does not look like a NixOS config checkout"; \
    exit 1; \
  fi

# Update channels (only relevant if channels are used)
channels-update:
  sudo nix-channel --update

# Tailscale helpers (only runs if tailscale exists)
ts-status:
  command -v tailscale >/dev/null 2>&1 && tailscale status || echo "tailscale not installed"

ts-up:
  command -v tailscale >/dev/null 2>&1 && sudo tailscale up || (echo "tailscale not installed" && exit 1)

# Convenience: open a root shell
root:
  sudo -i


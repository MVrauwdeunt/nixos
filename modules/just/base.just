# Global base Justfile (/etc/just/Justfile)
# Goal: useful on any host, without requiring the repo to be present.

set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# List available recipes by default
default:
  @just --list

# Show basic system info
info:
  hostnamectl
  nixos-version
  uname -a

# Remove SSH host key
ssh_remkey HOST:
  @echo "Removing SSH host key for {{HOST}}"
  @ssh-keygen -R {{HOST}}

# Quick overview: disk, memory, load, top processes
status:
  uptime
  df -h
  free -h || true
  ps aux --sort=-%cpu | head -n 15

# Show networking basics
net:
  ip -brief addr
  ip route
  resolvectl status || true

# Run an package in a temporary shell (not installed permanent)
run PKG +CMD:
  nix shell -p {{PKG}} {{CMD}}  

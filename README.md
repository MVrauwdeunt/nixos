# NixOS infra (flakes)

Declarative setup for multiple hosts (Hetzner + Proxmox) using NixOS flakes.
Current status: **bifrost** (Hetzner, BIOS, non-disko).

## Quick start

```bash
# from within this repo
sudo nixos-rebuild switch --flake .#bifrost
nix flake show .
```

## Add a new host (minimal interaction)

1. Add one line to the `hosts` list in `flake.nix`, for example:
   ```nix
   { name = "thor"; platform = "proxmox"; firmware = "uefi"; disk = "/dev/sda"; useDisko = true; }
   ```
   > ⚠️ `useDisko = true` is **destructive**: it wipes the specified disk. Choose `firmware = "bios"` or `"uefi"` based on your VM/host.

2. Install from your workstation or an existing machine:
   ```bash
   nix run github:nix-community/nixos-anywhere --      --flake .#thor root@<host-ip>
   ```

## Repo layout (short)

```
modules/
  base.nix
  ssh-hardened.nix
  users/zanbee.nix
  network/{hetzner-cloud.nix, proxmox-bridge.nix}
  disko-{bios,uefi}-ext4.nix
hosts/
  bifrost/
    default.nix
    hardware-configuration.nix   # only needed for non-disko hosts
flake.nix
```

## Useful commands

```bash
# update inputs (refresh pins)
nix flake update

# rebuild using an explicit path (avoids cwd confusion)
sudo nixos-rebuild switch --flake /home/zanbee/projects/nixos#bifrost

# rollback to previous system generation
sudo nixos-rebuild switch --rollback
```

## Tips & pitfalls

- **Flakes + Git**: commit your changes; untracked files are ignored by flakes.
- **Hostnames**: case-sensitive; `name = "bifrost"` → selector `#bifrost`, path `hosts/bifrost/`.
- **Root SSH**: disabled; log in as user `zanbee` (wheel) with your SSH key.
- **Hetzner**: IPv4 via DHCP /32 + IPv6 RA are handled by `modules/network/hetzner-cloud.nix`.
- **Proxmox**: choose BIOS (simple) or UEFI (OVMF + EFI disk) and the matching disko module.

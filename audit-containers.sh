
#!/usr/bin/env bash
set -euo pipefail

declare -A hosts=(
  [mimir]="192.168.178.240"
  [sif]="192.168.100.150"
  [vili]="100.78.198.109"
  [saga]="192.168.178.250"
)

for host in mimir sif vili saga; do
  echo
  echo "===== $host ====="

  # Gewenste images uit de NixOS flake
  desired=$(nix eval --json \
    ".#nixosConfigurations.${host}.config.virtualisation.oci-containers.containers" \
    | jq -r '
        to_entries[]
        | [.key, (.value.image | split("@") | last)]
        | @tsv
      ')

  # Werkelijk draaiende containers via SSH
  if ! actual=$(ssh -o BatchMode=yes \
    "zanbee@${hosts[$host]}" \
    "sudo -n podman ps -a --format '{{.Names}}|{{.Image}}|{{.Status}}'"); then
    echo "ERROR: SSH of sudo-toegang mislukt"
    continue
  fi

  while IFS=$'\t' read -r name digest; do
    line=$(printf '%s\n' "$actual" |
      awk -F '|' -v n="$name" '$1 == n {print; exit}')

    if [[ -z "$line" ]]; then
      printf 'MISSING  %-25s\n' "$name"
      continue
    fi

    IFS='|' read -r _ image status <<< "$line"

    if [[ "$image" == *"@$digest" ]]; then
      if [[ "$status" == Up* ]]; then
        printf 'OK       %s\n' "$name"
      else
        printf 'STOPPED  %s (%s)\n' "$name" "$status"
      fi
    else
      printf 'MISMATCH %s\n' "$name"
      printf '  Git:     %s\n' "$digest"
      printf '  Runtime: %s\n' "$image"
    fi
  done <<< "$desired"

  # Containers die niet in de NixOS-configuratie staan
  while IFS='|' read -r name image status; do
    if ! grep -Fq "$(printf '%s\t' "$name")" <<< "$desired"; then
      printf 'EXTRA    %s (%s)\n' "$name" "$status"
    fi
  done <<< "$actual"
done

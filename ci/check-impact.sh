#!/usr/bin/env bash

set -euo pipefail

repo=$(git rev-parse --show-toplevel)
cd "$repo"

base=$(git rev-parse "${1:-HEAD^1}^{commit}")
head=$(git rev-parse "${2:-HEAD}^{commit}")

tmpDir=$(mktemp -d)
trap 'rm -rf "$tmpDir"' EXIT

echo "Infrastructure impact analysis"
echo "Base: $base"
echo "Head: $head"
echo

evaluate() {
  local revision="$1"

  nix eval \
    --json \
    --no-update-lock-file \
    "git+file://${repo}?rev=${revision}#nixosConfigurations" \
    --apply 'hosts: builtins.mapAttrs
      (name: host: host.config.system.build.toplevel.drvPath)
      hosts'
}

# Evaluate the exact committed configurations.
echo "Evaluating base configuration..."
evaluate "$base" > "$tmpDir/base.json"

echo "Evaluating head configuration..."
evaluate "$head" > "$tmpDir/head.json"

# Compare system derivations, including added and removed hosts.
jq -n \
  --slurpfile base "$tmpDir/base.json" \
  --slurpfile head "$tmpDir/head.json" '
  $base[0] as $b |
  $head[0] as $h |

  (($b | keys) + ($h | keys) | unique) |
  map(
    . as $host |
    {
      host: $host,
      status: (
        if ($b | has($host) | not) then "ADDED"
        elif ($h | has($host) | not) then "REMOVED"
        elif $b[$host] != $h[$host] then "CHANGED"
        else "UNCHANGED"
        end
      )
    }
  )
' > "$tmpDir/impact.json"

echo
echo "=== Infrastructure impact report ==="
echo

printf "%-24s %s\n" "HOST" "STATUS"
printf "%-24s %s\n" "------------------------" "----------"

jq -r '.[] | [.host, .status] | @tsv' \
  "$tmpDir/impact.json" |
while IFS=$'\t' read -r host status; do
  printf "%-24s %s\n" "$host" "$status"
done

echo

jq -r '
  "Total systems: \(length)",
  "Changed:       \([.[] | select(.status == "CHANGED")] | length)",
  "Unchanged:     \([.[] | select(.status == "UNCHANGED")] | length)",
  "Added:         \([.[] | select(.status == "ADDED")] | length)",
  "Removed:       \([.[] | select(.status == "REMOVED")] | length)"
' "$tmpDir/impact.json"

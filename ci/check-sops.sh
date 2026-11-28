#!/usr/bin/env bash

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

policy=$(yq -o=json 'explode(.) | .creation_rules' .sops.yaml)

failed=0

# Verify that required secret files are tracked by Git.
required_files=(
  "secrets.yaml"
  "hosts/brokkr/secrets.yaml"
  "hosts/installer/secrets.yaml"
)

for file in "${required_files[@]}"; do
  if ! git ls-files --error-unmatch "$file" >/dev/null 2>&1 ||
     [[ ! -f "$file" ]]; then
    echo "FAIL: Missing required file: $file"
    failed=1
  fi
done

# Validate all tracked SOPS secret files.
while IFS= read -r -d '' file; do
  [[ "${file##*/}" == "secrets.yaml" ]] || continue

  echo "Checking $file"

  # Verify encryption status without decrypting.
  if ! sops filestatus "$file" |
    jq -e '.encrypted == true' >/dev/null; then
    echo "FAIL: File is not recognized as encrypted"
    failed=1
    continue
  fi

  # Select the first matching SOPS creation rule.
  if ! rule=$(jq -ce --arg file "$file" '
    map(select(.path_regex as $pattern |
      $file | test($pattern)))
    | first
    | select(. != null)
  ' <<< "$policy"); then
    echo "FAIL: No matching SOPS creation rule"
    failed=1
    continue
  fi

  # Only support the current single-group age policy.
  if ! jq -e '
    (.key_groups | length) == 1 and
    (.key_groups[0] | keys) == ["age"] and
    (.key_groups[0].age | length) > 0
  ' <<< "$rule" >/dev/null; then
    echo "FAIL: Unsupported SOPS key group configuration"
    failed=1
    continue
  fi

  expected=$(jq -c '.key_groups[0].age | sort' <<< "$rule")

  # Inspect encryption metadata without exposing secret values.
  if ! metadata=$(yq -o=json '.sops' "$file"); then
    echo "FAIL: Unable to read SOPS metadata"
    failed=1
    continue
  fi

  if ! jq -e '
    (.version | type == "string") and
    (.mac | type == "string" and startswith("ENC[")) and
    (.lastmodified != null) and
    (.age | type == "array" and length > 0) and
    all(.age[];
      (.recipient | type == "string") and
      (.enc | type == "string" and length > 0)
    ) and
    ((.pgp // []) | length == 0) and
    ((.kms // []) | length == 0) and
    ((.gcp_kms // []) | length == 0) and
    ((.azure_kv // []) | length == 0) and
    ((.hc_vault // []) | length == 0) and
    ((.key_groups // []) | length == 0)
  ' <<< "$metadata" >/dev/null; then
    echo "FAIL: Invalid or unsupported SOPS metadata"
    failed=1
    continue
  fi

  actual=$(jq -c '[.age[].recipient] | sort' <<< "$metadata")

  if [[ "$expected" != "$actual" ]]; then
    echo "FAIL: Recipient mismatch"
    echo "Expected: $expected"
    echo "Actual:   $actual"
    failed=1
    continue
  fi

  echo "PASS: Encryption metadata and recipients"
done < <(git ls-files -z)

if [[ "$failed" -ne 0 ]]; then
  echo "SOPS validation failed."
  exit 1
fi

echo "All SOPS checks passed."

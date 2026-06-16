#!/usr/bin/env sh
set -eu

readme_file="${1:-mesh/README.md}"
readme_text="$(cat "$readme_file")"

for token in \
  '`peer-authentication.yaml`' \
  '`destination-rule.yaml`' \
  '`virtual-service-retry.yaml`' \
  '`authorization-policy.yaml`' \
  '`kiali-access.md`' \
  'service-mesh-test-plan.md' \
  'service-mesh-results.md'
do
  printf '%s' "$readme_text" | grep -F -q "$token" || {
    printf 'mesh/README.md is missing required token %s.\n' "$token" >&2
    exit 1
  }
done

printf 'mesh/README.md is aligned with the current service-mesh scaffold files and supporting docs.\n'

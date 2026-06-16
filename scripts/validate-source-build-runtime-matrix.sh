#!/usr/bin/env sh
set -eu

. scripts/catalog.sh

matrix_file="${1:-docs/source-build-runtime-matrix.md}"
matrix_text="$(cat "$matrix_file")"
services_file="$(resolve_services_file)"

iter_catalog_services "$services_file" | while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
  printf '%s' "$matrix_text" | grep -F -q "\`$service\`" || {
    printf 'docs/source-build-runtime-matrix.md is missing service `%s`.\n' "$service" >&2
    exit 1
  }
done

while IFS='|' read -r service category suite message || [ -n "${service}${category}${suite}${message}" ]; do
  [ -n "${service:-}" ] || continue
  printf '%s' "$matrix_text" | grep -F -q "\`$service\`" || {
    printf 'docs/source-build-runtime-matrix.md is missing blocker service `%s`.\n' "$service" >&2
    exit 1
  }
done <<EOF
$(powershell -ExecutionPolicy Bypass -File scripts/summarize-failsafe-blockers.ps1)
EOF

printf '%s' "$matrix_text" | grep -F -q '`helm lint helm/yas`' || {
  printf 'docs/source-build-runtime-matrix.md should mention `helm lint helm/yas`.\n' >&2
  exit 1
}

printf '%s' "$matrix_text" | grep -F -q '`helm template yas helm/yas`' || {
  printf 'docs/source-build-runtime-matrix.md should mention `helm template yas helm/yas`.\n' >&2
  exit 1
}

printf 'docs/source-build-runtime-matrix.md covers the current catalog and blocker summary.\n'

#!/usr/bin/env sh
set -eu

. scripts/catalog.sh

matrix_file="${1:-docs/image-matrix.md}"
matrix_text="$(cat "$matrix_file")"
services_file="$(resolve_services_file)"

iter_catalog_services "$services_file" | while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
  printf '%s' "$matrix_text" | grep -F -q "| ${service} |" || {
    printf 'docs/image-matrix.md is missing table row for service %s.\n' "$service" >&2
    exit 1
  }
done

for blocked_service in sampledata search; do
  printf '%s' "$matrix_text" | grep -E -q "\| ${blocked_service} \|.*blocked" || {
    printf 'docs/image-matrix.md should note that %s still has a blocked full test path.\n' "$blocked_service" >&2
    exit 1
  }
done

printf '%s' "$matrix_text" | grep -F -q 'work/service-verification.generated.md' || {
  printf 'docs/image-matrix.md should reference the generated service verification matrix.\n' >&2
  exit 1
}

printf '%s' "$matrix_text" | grep -F -q 'scripts\report-status.ps1 -SkipCommandChecks' || {
  printf 'docs/image-matrix.md should point to scripts\\report-status.ps1 -SkipCommandChecks as the evidence refresh entrypoint.\n' >&2
  exit 1
}

printf 'docs/image-matrix.md covers the current catalog and blocked-image notes.\n'

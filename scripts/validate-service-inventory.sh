#!/usr/bin/env sh
set -eu

. scripts/catalog.sh

inventory_file="${1:-docs/service-inventory.md}"
inventory_text="$(cat "$inventory_file")"
full_catalog="jenkins/services.env"
baseline_catalog="jenkins/services.release-baseline.env"

baseline_services="$(iter_catalog_services "$baseline_catalog" | while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
  printf '%s\n' "$service"
done)"

iter_catalog_services "$full_catalog" | while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
  service_row="$(printf '%s\n' "$inventory_text" | grep -F "| $service |" | head -n 1 || true)"
  [ -n "$service_row" ] || {
    printf 'docs/service-inventory.md is missing row for service %s.\n' "$service" >&2
    exit 1
  }

  printf '%s' "$service_row" | grep -F -q "| \`$path\` |" || {
    printf 'docs/service-inventory.md is missing path `%s` for service %s.\n' "$path" "$service" >&2
    exit 1
  }

  printf '%s' "$service_row" | grep -F -q "| \`$dockerfile\` |" || {
    printf 'docs/service-inventory.md is missing Dockerfile `%s` for service %s.\n' "$dockerfile" "$service" >&2
    exit 1
  }

  printf '%s' "$service_row" | grep -F -q "| \`$port\` |" || {
    printf 'docs/service-inventory.md is missing container port `%s` for service %s.\n' "$port" "$service" >&2
    exit 1
  }

  printf '%s' "$service_row" | grep -F -q "| \`$workload_type\` |" || {
    printf 'docs/service-inventory.md is missing workload type `%s` for service %s.\n' "$workload_type" "$service" >&2
    exit 1
  }

  recommended='no'
  printf '%s\n' "$baseline_services" | grep -F -x -q "$service" && recommended='yes'
  printf '%s' "$service_row" | grep -F -q "| $recommended |" || {
    printf 'docs/service-inventory.md is missing recommended-first-release value %s for service %s.\n' "$recommended" "$service" >&2
    exit 1
  }

  if [ "$expose" = 'true' ]; then
    printf '%s' "$service_row" | grep -F -q "| \`$node_port\` |" || {
      printf 'docs/service-inventory.md is missing nodePort `%s` for service %s.\n' "$node_port" "$service" >&2
      exit 1
    }
  fi
done

for required_reference in \
  'jenkins/services.release-baseline.env' \
  'jenkins/services.env' \
  'work/service-verification.generated.md' \
  'work/host-capabilities.generated.md' \
  'scripts\refresh-evidence.ps1 -SkipCommandChecks'
do
  printf '%s' "$inventory_text" | grep -F -q "$required_reference" || {
    printf 'docs/service-inventory.md should reference %s.\n' "$required_reference" >&2
    exit 1
  }
done

printf 'docs/service-inventory.md is aligned with the full catalog, frozen baseline, and generated verification snapshot.\n'

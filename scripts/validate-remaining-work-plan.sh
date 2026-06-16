#!/usr/bin/env sh
set -eu

plan_file="${1:-docs/remaining-work-plan.md}"
plan_text="$(cat "$plan_file")"
baseline_services_file="jenkins/services.release-baseline.env"

while IFS='|' read -r service path dockerfile port expose node_port workload_type || [ -n "${service}${path}${dockerfile}${port}${expose}${node_port}${workload_type}" ]; do
  case "${service:-}" in
    ''|\#*)
      continue
      ;;
  esac

  printf '%s' "$plan_text" | grep -F -q "\`$service\`" || {
    printf 'docs/remaining-work-plan.md is missing frozen baseline service `%s`.\n' "$service" >&2
    exit 1
  }
done < "$baseline_services_file"

while IFS='|' read -r service category suite message || [ -n "${service}${category}${suite}${message}" ]; do
  [ -n "${service:-}" ] || continue
  printf '%s' "$plan_text" | grep -F -q "\`$service\`" || {
    printf 'docs/remaining-work-plan.md is missing blocker service `%s`.\n' "$service" >&2
    exit 1
  }
done <<EOF
$(powershell -ExecutionPolicy Bypass -File scripts/summarize-failsafe-blockers.ps1)
EOF

for required_reference in \
  'jenkins/services.release-baseline.env' \
  'status-report.md' \
  'work/service-verification.generated.md' \
  'work/host-capabilities.generated.md' \
  'Jenkins agent' \
  'scripts\refresh-evidence.ps1 -SkipCommandChecks'
do
  printf '%s' "$plan_text" | grep -F -q "$required_reference" || {
    printf 'docs/remaining-work-plan.md should reference %s.\n' "$required_reference" >&2
    exit 1
  }
done

printf 'docs/remaining-work-plan.md is aligned with the frozen baseline and current blocker set.\n'

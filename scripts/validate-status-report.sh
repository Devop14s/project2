#!/usr/bin/env sh
set -eu

status_report="${1:-docs/status-report.md}"

required_full_build_services="
storefront
backoffice
storefront-bff
backoffice-bff
product
payment
payment-paypal
recommendation
inventory
order
"

status_text="$(cat "$status_report")"

for service in $required_full_build_services; do
  printf '%s' "$status_text" | grep -F -q "\`$service\`" || {
    printf 'docs/status-report.md is missing verified service `%s`.\n' "$service" >&2
    exit 1
  }
done

while IFS='|' read -r service category suite message || [ -n "${service}${category}${suite}${message}" ]; do
  [ -n "${service:-}" ] || continue
  printf '%s' "$status_text" | grep -F -q "\`$service\`" || {
    printf 'docs/status-report.md is missing blocker service `%s`.\n' "$service" >&2
    exit 1
  }
done <<EOF
$(powershell -ExecutionPolicy Bypass -File scripts/summarize-failsafe-blockers.ps1)
EOF

printf '%s' "$status_text" | grep -F -q 'work/service-verification.generated.md' || {
  printf 'docs/status-report.md should reference the generated service verification matrix.\n' >&2
  exit 1
}

printf '%s' "$status_text" | grep -F -q 'remaining-work-plan.md' || {
  printf 'docs/status-report.md should still point to remaining-work-plan.md.\n' >&2
  exit 1
}

printf 'docs/status-report.md is aligned with the current blocker and verification summary.\n'

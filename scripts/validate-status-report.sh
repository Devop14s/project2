#!/usr/bin/env sh
set -eu

status_report="${1:-docs/status-report.md}"
blockers_command='sh scripts/summarize-failsafe-blockers.sh'

if command -v powershell >/dev/null 2>&1; then
  blockers_command='powershell -ExecutionPolicy Bypass -File scripts/summarize-failsafe-blockers.ps1'
fi

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
$($blockers_command)
EOF

printf '%s' "$status_text" | grep -F -q 'work/service-verification.generated.md' || {
  printf 'docs/status-report.md should reference the generated service verification matrix.\n' >&2
  exit 1
}

printf '%s' "$status_text" | grep -F -q 'remaining-work-plan.md' || {
  printf 'docs/status-report.md should still point to remaining-work-plan.md.\n' >&2
  exit 1
}

printf '%s' "$status_text" | grep -F -q 'work/final-report-notes.generated.md' || {
  printf 'docs/status-report.md should reference work/final-report-notes.generated.md.\n' >&2
  exit 1
}

printf '%s' "$status_text" | grep -F -q 'work/host-capabilities.generated.md' || {
  printf 'docs/status-report.md should reference work/host-capabilities.generated.md.\n' >&2
  exit 1
}

printf '%s' "$status_text" | grep -F -q 'scripts\refresh-evidence.ps1 -SkipCommandChecks' || {
  printf 'docs/status-report.md should point to scripts\\refresh-evidence.ps1 -SkipCommandChecks as the evidence refresh entrypoint.\n' >&2
  exit 1
}

printf 'docs/status-report.md is aligned with the current blocker and verification summary.\n'

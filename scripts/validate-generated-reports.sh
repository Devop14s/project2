#!/usr/bin/env sh
set -eu

status_report_file="${1:-work/status-report.generated.md}"
service_verification_file="${2:-work/service-verification.generated.md}"
services_file="${3:-jenkins/services.env}"
release_baseline_services_file="${4:-jenkins/services.release-baseline.env}"

for required_file in \
  "$status_report_file" \
  "$service_verification_file" \
  "$services_file" \
  "$release_baseline_services_file"
do
  [ -f "$required_file" ] || {
    printf 'Required file not found: %s\n' "$required_file" >&2
    exit 1
  }
done

status_text="$(cat "$status_report_file")"
service_verification_text="$(cat "$service_verification_file")"

service_count=0
release_baseline_service_count=0
public_entry_count=0
ui_count=0
backend_count=0
services_tmp="$(mktemp "${TMPDIR:-/tmp}/yas-generated-services.XXXXXX")"
blockers_tmp="$(mktemp "${TMPDIR:-/tmp}/yas-generated-blockers.XXXXXX")"
trap 'rm -f "$services_tmp" "$blockers_tmp"' EXIT INT TERM

while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
  [ -n "${service:-}" ] || continue
  printf '%s\n' "$service" >> "$services_tmp"
  service_count=$((service_count + 1))
  if [ "$expose" = "true" ]; then
    public_entry_count=$((public_entry_count + 1))
  fi
  if [ "$workload_type" = "ui" ]; then
    ui_count=$((ui_count + 1))
  elif [ "$workload_type" = "backend" ]; then
    backend_count=$((backend_count + 1))
  fi
done <<EOF
$(iter_catalog_services "$services_file")
EOF

while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
  [ -n "${service:-}" ] || continue
  release_baseline_service_count=$((release_baseline_service_count + 1))
done <<EOF
$(iter_catalog_services "$release_baseline_services_file")
EOF

for token in \
  '# Generated Status Report' \
  "- Services in catalog: ${service_count}" \
  "- Services in release baseline: ${release_baseline_service_count}" \
  "- Public entrypoints in catalog: ${public_entry_count}" \
  "- UI workloads in catalog: ${ui_count}" \
  "- Backend workloads in catalog: ${backend_count}" \
  'Drift validators now lock the main hand-written docs and runbooks' \
  'Real Kubernetes deployment cannot be executed.' \
  'Jenkins credentials and webhook integration cannot be verified locally.'
do
  printf '%s' "$status_text" | grep -F -q "$token" || {
    printf 'Generated status report is missing required token %s.\n' "$token" >&2
    exit 1
  }
done

while IFS= read -r service; do
  [ -n "$service" ] || continue
  printf '%s' "$service_verification_text" | grep -F -q "| ${service} |" || {
    printf 'Generated service verification matrix is missing row for service %s.\n' "$service" >&2
    exit 1
  }
done < "$services_tmp"

for token in \
  '# Service Verification Matrix' \
  '| Service | Workload | Build evidence | Local image | Blocker | Overall status |' \
  '| storefront | ui |' \
  '| backoffice | ui |' \
  '| product | backend |' \
  '| sampledata | backend |' \
  '| search | backend |' \
  'keycloak:' \
  'elasticsearch:' \
  'compile:' \
  'full build verified' \
  'full test path blocked'
do
  printf '%s' "$service_verification_text" | grep -F -q "$token" || {
    printf 'Generated service verification matrix is missing required token %s.\n' "$token" >&2
    exit 1
  }
done

sh scripts/summarize-failsafe-blockers.sh "$blockers_tmp" >/dev/null
while IFS='|' read -r service category suite message || [ -n "${service}${category}${suite}${message}" ]; do
  [ -n "${service:-}" ] || continue
  expected_blocker_token="${category}: ${suite}"
  printf '%s' "$service_verification_text" | grep -F -q "| ${service} |" || {
    printf 'Generated service verification matrix is missing blocker row for service %s.\n' "$service" >&2
    exit 1
  }
  printf '%s' "$service_verification_text" | grep -F -q "$expected_blocker_token" || {
    printf 'Generated service verification matrix is missing blocker token %s for service %s.\n' "$expected_blocker_token" "$service" >&2
    exit 1
  }
done < "$blockers_tmp"

printf 'Generated status and service-verification reports are aligned with the current catalog, validator coverage, and blocker summary.\n'

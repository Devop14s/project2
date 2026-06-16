#!/usr/bin/env sh
set -eu

output_file="${1:-work/status-report.generated.md}"
service_verification_file="${SERVICE_VERIFICATION_FILE:-work/service-verification.generated.md}"
final_report_notes_file="${FINAL_REPORT_NOTES_FILE:-work/final-report-notes.generated.md}"
host_capabilities_file="${HOST_CAPABILITIES_FILE:-work/host-capabilities.generated.md}"
skip_command_checks=0

if [ "${2:-}" = "--skip-command-checks" ] || [ "${1:-}" = "--skip-command-checks" ]; then
  skip_command_checks=1
  if [ "${1:-}" = "--skip-command-checks" ]; then
    output_file="work/status-report.generated.md"
  fi
fi

if [ "$skip_command_checks" -eq 1 ]; then
  SERVICE_VERIFICATION_FILE="$service_verification_file" \
  FINAL_REPORT_NOTES_FILE="$final_report_notes_file" \
  HOST_CAPABILITIES_FILE="$host_capabilities_file" \
  sh scripts/report-status.sh "$output_file" --skip-command-checks
else
  SERVICE_VERIFICATION_FILE="$service_verification_file" \
  FINAL_REPORT_NOTES_FILE="$final_report_notes_file" \
  HOST_CAPABILITIES_FILE="$host_capabilities_file" \
  sh scripts/report-status.sh "$output_file"
fi

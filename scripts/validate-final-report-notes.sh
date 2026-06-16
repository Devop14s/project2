#!/usr/bin/env sh
set -eu

notes_file="${1:-work/final-report-notes.generated.md}"
baseline_services_file="${2:-jenkins/services.release-baseline.env}"
notes_text="$(cat "$notes_file")"

for token in \
  '# Final Report Notes' \
  'docs/final-report-template.md' \
  'work/status-report.generated.md' \
  'work/service-verification.generated.md' \
  'work/host-capabilities.generated.md' \
  'work/image-digests.txt' \
  'work/commit-metadata.json' \
  'work/runtime-evidence/<namespace>/<release>/' \
  'work/cleanup-evidence/<namespace>/<release>/' \
  'work/manifest-update-metadata.json' \
  'scripts\refresh-evidence.ps1 -SkipCommandChecks' \
  'Verified locally only:' \
  'Current host capability evidence:' \
  'Verified end to end on real infrastructure:'
do
  printf '%s' "$notes_text" | grep -F -q "$token" || {
    printf 'Generated final report notes are missing required token %s.\n' "$token" >&2
    exit 1
  }
done

while IFS='|' read -r service path dockerfile port expose node_port workload_type || [ -n "${service}${path}${dockerfile}${port}${expose}${node_port}${workload_type}" ]; do
  case "${service:-}" in
    ''|\#*)
      continue
      ;;
  esac

  printf '%s' "$notes_text" | grep -F -q "- \`${service}\`" || {
    printf 'Generated final report notes are missing baseline service `%s`.\n' "$service" >&2
    exit 1
  }
done < "$baseline_services_file"

printf 'Generated final report notes are aligned with the current baseline subset and evidence handoff paths.\n'

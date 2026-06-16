#!/usr/bin/env sh
set -eu

template_file="${1:-docs/final-report-template.md}"
template_text="$(cat "$template_file")"

for token in \
  'work/image-digests.txt' \
  'work/cleanup-evidence/<namespace>/<release>/' \
  'work/commit-metadata.json' \
  'work/runtime-evidence/<namespace>/<release>/copied-artifacts.txt' \
  'ArgoCD' \
  'Service mesh' \
  'scaffold-only' \
  'verified end to end on real infrastructure'
do
  printf '%s' "$template_text" | grep -F -q "$token" || {
    printf 'docs/final-report-template.md is missing required token %s.\n' "$token" >&2
    exit 1
  }
done

printf 'docs/final-report-template.md is aligned with the current evidence and reporting requirements.\n'

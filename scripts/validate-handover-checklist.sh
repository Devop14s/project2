#!/usr/bin/env sh
set -eu

checklist_file="${1:-docs/handover-checklist.md}"
checklist_text="$(cat "$checklist_file")"

for token in \
  '`release-baseline`' \
  '`full`' \
  '`DOCKERHUB_NAMESPACE`' \
  '`dockerhub-creds`' \
  '`kubeconfig-file`' \
  '`yas-ci`' \
  '`yas-developer-build`' \
  '`yas-developer-cleanup`' \
  '`yas-dev-cd`' \
  '`yas-staging-release`' \
  '`work/final-report-notes.generated.md`' \
  '`work/host-capabilities.generated.md`' \
  '`work/runtime-evidence/<namespace>/<release>/`' \
  '`work/manifest-update-metadata.json`' \
  'host or Jenkins agent' \
  'scripts\refresh-evidence.ps1 -SkipCommandChecks' \
  'sampledata' \
  'search' \
  'Keycloak'
do
  printf '%s' "$checklist_text" | grep -F -q "$token" || {
    printf 'docs/handover-checklist.md is missing required token %s.\n' "$token" >&2
    exit 1
  }
done

printf 'docs/handover-checklist.md is aligned with the current registry, Jenkins, cluster, GitOps, and blocker handover scope.\n'

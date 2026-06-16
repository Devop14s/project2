#!/usr/bin/env sh
set -eu

readme_file="${1:-README.md}"
readme_text="$(cat "$readme_file")"

for token in \
  'docs/status-report.md' \
  'docs/remaining-work-plan.md' \
  'work/service-verification.generated.md' \
  'work/final-report-notes.generated.md' \
  'scripts\report-status.ps1 -SkipCommandChecks' \
  'jenkins/services.release-baseline.env' \
  '`storefront`' \
  '`backoffice`' \
  '`product`' \
  '`payment`' \
  '`inventory`' \
  '`order`' \
  '`cart`' \
  '`customer`' \
  '`location`' \
  '`media`' \
  '`promotion`' \
  '`rating`' \
  '`tax`' \
  '`webhook`' \
  '`sampledata`' \
  '`search`'
do
  printf '%s' "$readme_text" | grep -F -q "$token" || {
    printf 'README.md is missing required token %s.\n' "$token" >&2
    exit 1
  }
done

printf 'README.md is aligned with the current verified scope, baseline catalog, and generated evidence references.\n'

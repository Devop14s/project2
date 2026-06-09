#!/usr/bin/env sh
set -eu

. scripts/catalog.sh

services_file="$(resolve_services_file)"
values_file="${VALUES_FILE:-helm/yas/values.yaml}"
temp_file="${TMPDIR:-/tmp}/yas-chart-values.$$"
normalized_expected_file="${TMPDIR:-/tmp}/yas-chart-values-expected.$$"
normalized_actual_file="${TMPDIR:-/tmp}/yas-chart-values-actual.$$"

[ -f "$values_file" ] || {
  printf 'Values file not found: %s\n' "$values_file" >&2
  exit 1
}

cleanup() {
  rm -f "$temp_file" "$normalized_expected_file" "$normalized_actual_file"
}

trap cleanup EXIT INT TERM

SERVICES_FILE="$services_file" OUTPUT_FILE="$temp_file" sh scripts/generate-chart-values.sh >/dev/null

awk '{ sub(/\r$/, ""); print }' "$temp_file" > "$normalized_expected_file"
awk '{ sub(/\r$/, ""); print }' "$values_file" > "$normalized_actual_file"

if ! cmp -s "$normalized_expected_file" "$normalized_actual_file"; then
  printf 'Chart values drift detected between %s and %s\n' "$services_file" "$values_file" >&2
  exit 1
fi

printf 'Chart values are in sync: %s\n' "$values_file"

#!/usr/bin/env sh
set -eu

services_file="${SERVICES_FILE:-jenkins/services.env}"
values_file="${VALUES_FILE:-helm/yas/values.yaml}"
temp_file="${TMPDIR:-/tmp}/yas-chart-values.$$"

[ -f "$values_file" ] || {
  printf 'Values file not found: %s\n' "$values_file" >&2
  exit 1
}

cleanup() {
  rm -f "$temp_file"
}

trap cleanup EXIT INT TERM

SERVICES_FILE="$services_file" OUTPUT_FILE="$temp_file" sh scripts/generate-chart-values.sh >/dev/null

if ! cmp -s "$temp_file" "$values_file"; then
  printf 'Chart values drift detected between %s and %s\n' "$services_file" "$values_file" >&2
  exit 1
fi

printf 'Chart values are in sync: %s\n' "$values_file"

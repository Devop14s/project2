#!/usr/bin/env sh
set -eu

. scripts/catalog.sh
. scripts/source-root.sh

services_file="$(resolve_services_file)"
source_root="$(resolve_source_root)"

[ -f "$services_file" ] || {
  printf 'Services file not found: %s\n' "$services_file" >&2
  exit 1
}

[ -d "$source_root" ] || {
  printf 'Source root not found: %s\n' "$source_root" >&2
  exit 1
}

line_number=0
failed=0
normalized_services_file="$(mktemp "${TMPDIR:-/tmp}/yas-source-alignment.XXXXXX")"
trap 'rm -f "$normalized_services_file"' EXIT INT TERM

iter_catalog_services "$services_file" > "$normalized_services_file"

while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
  line_number=$((line_number + 1))

  if [ ! -d "${source_root}/${path}" ]; then
    printf "Line %s service '%s' path not found in source: %s/%s\n" "$line_number" "$service" "$source_root" "$path" >&2
    failed=1
  fi

  if [ ! -f "${source_root}/${dockerfile}" ]; then
    printf "Line %s service '%s' Dockerfile not found in source: %s/%s\n" "$line_number" "$service" "$source_root" "$dockerfile" >&2
    failed=1
  fi
done < "$normalized_services_file"

if [ "$failed" -ne 0 ]; then
  exit 1
fi

printf 'Service catalog matches source tree: %s\n' "$source_root"

#!/usr/bin/env sh
set -eu

. scripts/catalog.sh

services_file="${1:-}"
if [ -z "$services_file" ]; then
  services_file="$(resolve_services_file)"
fi
reference_services_file="${2:-}"

[ -f "$services_file" ] || {
  printf 'Services file not found: %s\n' "$services_file" >&2
  exit 1
}

tmp_names="${TMPDIR:-/tmp}/yas-services-names.$$"
tmp_node_ports="${TMPDIR:-/tmp}/yas-services-nodeports.$$"
tmp_service_lines="${TMPDIR:-/tmp}/yas-services-lines.$$"
tmp_reference_lines="${TMPDIR:-/tmp}/yas-reference-lines.$$"
tmp_normalized_services="${TMPDIR:-/tmp}/yas-services-normalized.$$"
tmp_normalized_reference="${TMPDIR:-/tmp}/yas-reference-normalized.$$"
trap 'rm -f "$tmp_names" "$tmp_node_ports" "$tmp_service_lines" "$tmp_reference_lines" "$tmp_normalized_services" "$tmp_normalized_reference"' EXIT INT TERM
: > "$tmp_names"
: > "$tmp_node_ports"
: > "$tmp_service_lines"

iter_catalog_services "$services_file" > "$tmp_normalized_services"

line_number=0
errors=0

while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
  line_number=$((line_number + 1))

  [ -n "$service" ] || {
    printf 'Line %s has an empty service name\n' "$line_number" >&2
    errors=1
  }

  if grep -qx "$service" "$tmp_names"; then
    printf 'Duplicate service name: %s\n' "$service" >&2
    errors=1
  else
    printf '%s\n' "$service" >> "$tmp_names"
    printf '%s|%s\n' "$service" "$line" >> "$tmp_service_lines"
  fi

  [ -n "$path" ] || {
    printf 'Line %s has an empty repo path\n' "$line_number" >&2
    errors=1
  }

  [ -n "$dockerfile" ] || {
    printf 'Line %s has an empty Dockerfile path\n' "$line_number" >&2
    errors=1
  }

  case "$port" in
    *[!0-9]*|'')
      printf 'Line %s has a non-numeric port: %s\n' "$line_number" "$port" >&2
      errors=1
      ;;
  esac

  case "$expose" in
    true|false) ;;
    *)
      printf 'Line %s expose value must be true or false\n' "$line_number" >&2
      errors=1
      ;;
  esac

  if [ "$expose" = "true" ]; then
    case "$node_port" in
      *[!0-9]*|'')
        printf 'Line %s must provide a numeric nodePort when expose=true\n' "$line_number" >&2
        errors=1
        ;;
      *)
        if grep -qx "$node_port" "$tmp_node_ports"; then
          printf 'Duplicate nodePort detected: %s\n' "$node_port" >&2
          errors=1
        else
          printf '%s\n' "$node_port" >> "$tmp_node_ports"
        fi
        ;;
    esac
  fi

  case "$workload_type" in
    ui|backend) ;;
    *)
      printf 'Line %s workloadType must be ui or backend\n' "$line_number" >&2
      errors=1
      ;;
  esac
done < "$tmp_normalized_services"

if [ "$errors" -eq 0 ] && [ -n "$reference_services_file" ]; then
  [ -f "$reference_services_file" ] || {
    printf 'Reference services file not found: %s\n' "$reference_services_file" >&2
    exit 1
  }

  : > "$tmp_reference_lines"
  iter_catalog_services "$reference_services_file" > "$tmp_normalized_reference"
  while IFS='|' read -r reference_service reference_path reference_dockerfile reference_port reference_expose reference_node_port reference_workload_type; do
    printf '%s|%s|%s|%s|%s|%s|%s|%s\n' \
      "$reference_service" \
      "$reference_service" \
      "$reference_path" \
      "$reference_dockerfile" \
      "$reference_port" \
      "$reference_expose" \
      "$reference_node_port" \
      "$reference_workload_type" >> "$tmp_reference_lines"
  done < "$tmp_normalized_reference"

  while IFS='|' read -r service service_line; do
    reference_entry="$(grep "^${service}|" "$tmp_reference_lines" || true)"
    if [ -z "$reference_entry" ]; then
      printf 'Service %s does not exist in reference catalog: %s\n' "$service" "$reference_services_file" >&2
      errors=1
      continue
    fi

    reference_line="${reference_entry#*|}"
    if [ "$reference_line" != "$service_line" ]; then
      printf 'Service %s differs from the reference catalog entry\n' "$service" >&2
      errors=1
    fi
  done < "$tmp_service_lines"
fi

if [ "$errors" -ne 0 ]; then
  exit 1
fi

printf 'Service catalog is valid: %s\n' "$services_file"

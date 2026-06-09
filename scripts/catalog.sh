#!/usr/bin/env sh

catalog_cr="$(printf '\r')"

catalog_file_for_selection() {
  case "${1:-full}" in
    ''|full)
      printf 'jenkins/services.env'
      ;;
    release-baseline)
      printf 'jenkins/services.release-baseline.env'
      ;;
    *)
      printf 'Unsupported SERVICE_CATALOG selection: %s\n' "$1" >&2
      return 1
      ;;
  esac
}

resolve_services_file() {
  if [ -n "${SERVICES_FILE:-}" ]; then
    printf '%s' "$SERVICES_FILE"
    return
  fi

  catalog_file_for_selection "${SERVICE_CATALOG:-full}"
}

strip_catalog_cr() {
  value="${1:-}"
  printf '%s' "${value%"$catalog_cr"}"
}

iter_catalog_services() {
  services_file="${1:-$(resolve_services_file)}"

  [ -f "$services_file" ] || {
    printf 'Services file not found: %s\n' "$services_file" >&2
    return 1
  }

  while IFS='|' read -r service path dockerfile port expose node_port workload_type || [ -n "${service}${path}${dockerfile}${port}${expose}${node_port}${workload_type}" ]; do
    service="$(strip_catalog_cr "$service")"
    path="$(strip_catalog_cr "$path")"
    dockerfile="$(strip_catalog_cr "$dockerfile")"
    port="$(strip_catalog_cr "$port")"
    expose="$(strip_catalog_cr "$expose")"
    node_port="$(strip_catalog_cr "$node_port")"
    workload_type="$(strip_catalog_cr "$workload_type")"

    [ -n "$service" ] || continue
    case "$service" in
      \#*) continue ;;
    esac

    printf '%s|%s|%s|%s|%s|%s|%s\n' \
      "$service" \
      "$path" \
      "$dockerfile" \
      "$port" \
      "$expose" \
      "$node_port" \
      "$workload_type"
  done < "$services_file"
}

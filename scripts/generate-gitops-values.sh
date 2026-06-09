#!/usr/bin/env sh
set -eu

. scripts/catalog.sh

services_file="$(resolve_services_file)"
all_services_file="jenkins/services.env"
tags_file="${TAGS_FILE:-}"
output_file="${OUTPUT_FILE:-work/gitops-values.yaml}"
environment_name="${ENVIRONMENT:-dev}"
namespace_name="${NAMESPACE:-yas-${environment_name}}"
domain_name="${DOMAIN_NAME:-storefront-${environment_name}.yas.local}"
backoffice_domain_name="${BACKOFFICE_DOMAIN_NAME:-backoffice-${environment_name}.yas.local}"
release_version="${RELEASE_VERSION:-main}"

[ -f "$services_file" ] || {
  printf 'Services file not found: %s\n' "$services_file" >&2
  exit 1
}

[ -f "$all_services_file" ] || {
  printf 'Reference services file not found: %s\n' "$all_services_file" >&2
  exit 1
}

mkdir -p "$(dirname "$output_file")"

if [ -n "$tags_file" ] && [ -f "$tags_file" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$tags_file"
  set +a
fi

selected_services_file="$(mktemp "${TMPDIR:-/tmp}/yas-selected-services.XXXXXX")"
trap 'rm -f "$selected_services_file"' EXIT INT TERM
iter_catalog_services "$services_file" | while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
  printf '%s\n' "$service" >> "$selected_services_file"
done

cat > "$output_file" <<EOF
global:
  environment: ${environment_name}
  namespace: ${namespace_name}
  domainName: ${domain_name}

services:
EOF

tag_var_name() {
  printf '%s_TAG' "$(printf '%s' "$1" | tr '[:lower:]-' '[:upper:]_')"
}

ingress_host_for() {
  service="$1"

  case "$service" in
    storefront)
      printf '%s' "$domain_name"
      ;;
    backoffice)
      printf '%s' "$backoffice_domain_name"
      ;;
    *)
      printf '%s-%s.yas.local' "$service" "$environment_name"
      ;;
  esac
}

iter_catalog_services "$all_services_file" | while IFS='|' read -r service path dockerfile port expose node_port workload_type; do

  if ! grep -qx "$service" "$selected_services_file"; then
    cat >> "$output_file" <<EOF
  ${service}:
    enabled: false
EOF
    continue
  fi

  tag_var="$(tag_var_name "$service")"
  tag_value="$(printenv "$tag_var" 2>/dev/null || printf '%s' "$release_version")"

  cat >> "$output_file" <<EOF
  ${service}:
    enabled: true
    image:
      tag: ${tag_value}
EOF

  if [ "$expose" = "true" ]; then
    cat >> "$output_file" <<EOF
    ingress:
      enabled: true
      host: $(ingress_host_for "$service")
EOF
  fi
done

printf 'Generated %s\n' "$output_file"

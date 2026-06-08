#!/usr/bin/env sh
set -eu

services_file="${SERVICES_FILE:-jenkins/services.env}"
tags_file="${TAGS_FILE:-}"
output_file="${OUTPUT_FILE:-work/gitops-values.yaml}"
environment_name="${ENVIRONMENT:-dev}"
namespace_name="${NAMESPACE:-yas-${environment_name}}"
domain_name="${DOMAIN_NAME:-storefront-${environment_name}.yas.local}"
release_version="${RELEASE_VERSION:-main}"

[ -f "$services_file" ] || {
  printf 'Services file not found: %s\n' "$services_file" >&2
  exit 1
}

mkdir -p "$(dirname "$output_file")"

if [ -n "$tags_file" ] && [ -f "$tags_file" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$tags_file"
  set +a
fi

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

while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
  [ -n "$service" ] || continue
  case "$service" in
    \#*) continue ;;
  esac

  tag_var="$(tag_var_name "$service")"
  tag_value="$(printenv "$tag_var" 2>/dev/null || printf '%s' "$release_version")"

  cat >> "$output_file" <<EOF
  ${service}:
    image:
      tag: ${tag_value}
EOF
done < "$services_file"

printf 'Generated %s\n' "$output_file"

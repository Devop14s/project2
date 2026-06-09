#!/usr/bin/env sh
set -eu

services_file="${SERVICES_FILE:-jenkins/services.env}"
tags_file="${TAGS_FILE:-work/branch-tags.env}"
output_file="${OUTPUT_FILE:-work/generated-values.yaml}"
environment_name="${ENVIRONMENT:-developer}"
deployer_id="${DEPLOYER_ID:-dev1}"
domain_name="${DOMAIN_NAME:-storefront-${deployer_id}.yas.local}"
backoffice_domain_name="${BACKOFFICE_DOMAIN_NAME:-backoffice-${deployer_id}.yas.local}"
namespace_name="${NAMESPACE:-yas-user-${deployer_id}}"
release_name="${RELEASE_NAME:-yas-${deployer_id}}"
release_version="${RELEASE_VERSION:-main}"
dockerhub_namespace="${DOCKERHUB_NAMESPACE:-}"

[ -n "$dockerhub_namespace" ] || {
  printf 'Missing DOCKERHUB_NAMESPACE\n' >&2
  exit 1
}

mkdir -p "$(dirname "$output_file")"

if [ -f "$tags_file" ]; then
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
  releaseName: ${release_name}

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
      printf '%s-%s.yas.local' "$service" "$deployer_id"
      ;;
  esac
}

while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
  [ -n "$service" ] || continue
  case "$service" in
    \#*) continue ;;
  esac

  tag_var="$(tag_var_name "$service")"
  tag_value="$(printenv "$tag_var" 2>/dev/null || printf '%s' "$release_version")"
  service_type="ClusterIP"

  if [ "$expose" = "true" ]; then
    service_type="NodePort"
  fi

  cat >> "$output_file" <<EOF
  ${service}:
    enabled: true
    workloadType: ${workload_type}
    image:
      repository: ${dockerhub_namespace}/yas-${service}
      tag: ${tag_value}
      pullPolicy: IfNotPresent
    containerPort: ${port}
    service:
      type: ${service_type}
      port: ${port}
EOF

  if [ "${workload_type}" = "backend" ]; then
    cat >> "$output_file" <<EOF
    metricPort: 8090
EOF
  fi

  if [ "$expose" = "true" ]; then
    cat >> "$output_file" <<EOF
      nodePort: ${node_port:-32080}
    ingress:
      enabled: true
      host: $(ingress_host_for "$service")
EOF
  fi
done < "$services_file"

printf 'Generated %s\n' "$output_file"

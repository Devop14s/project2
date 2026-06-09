#!/usr/bin/env sh
set -eu

. scripts/catalog.sh

services_file="$(resolve_services_file)"
output_file="${OUTPUT_FILE:-helm/yas/values.yaml}"
environment_name="${ENVIRONMENT:-default}"
namespace_name="${NAMESPACE:-default}"
domain_name="${DOMAIN_NAME:-yas.local}"
image_registry_namespace="${IMAGE_REGISTRY_NAMESPACE:-docker.io/example}"

[ -f "$services_file" ] || {
  printf 'Services file not found: %s\n' "$services_file" >&2
  exit 1
}

mkdir -p "$(dirname "$output_file")"

ingress_host_for() {
  service="$1"

  case "$service" in
    storefront)
      printf 'storefront.%s' "$domain_name"
      ;;
    backoffice)
      printf 'backoffice.%s' "$domain_name"
      ;;
    *)
      printf '%s.%s' "$service" "$domain_name"
      ;;
  esac
}

cat > "$output_file" <<EOF
global:
  environment: ${environment_name}
  namespace: ${namespace_name}
  domainName: ${domain_name}

services:
EOF

first_service=1
iter_catalog_services "$services_file" | while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
  if [ "$first_service" -eq 0 ]; then
    printf '\n' >> "$output_file"
  fi
  first_service=0

  service_type="ClusterIP"
  if [ "$expose" = "true" ]; then
    service_type="NodePort"
  fi

  cat >> "$output_file" <<EOF
  ${service}:
    enabled: true
    workloadType: ${workload_type}
    image:
      repository: ${image_registry_namespace}/yas-${service}
      tag: main
      pullPolicy: IfNotPresent
    containerPort: ${port}
EOF

  if [ "${workload_type}" = "backend" ]; then
    cat >> "$output_file" <<EOF
    metricPort: 8090
EOF
  fi

  cat >> "$output_file" <<EOF
    service:
      type: ${service_type}
      port: ${port}
EOF

  if [ "$expose" = "true" ]; then
    cat >> "$output_file" <<EOF
      nodePort: ${node_port:-32080}
    ingress:
      enabled: true
      host: $(ingress_host_for "$service")
EOF
  fi
done

printf 'Generated %s\n' "$output_file"

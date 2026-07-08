#!/usr/bin/env sh
set -eu

. scripts/catalog.sh

services_file="$(resolve_services_file)"
all_services_file="jenkins/services.env"
tags_file="${TAGS_FILE:-work/branch-tags.env}"
output_file="${OUTPUT_FILE:-work/generated-values.yaml}"
environment_name="${ENVIRONMENT:-developer}"
deployer_id="${DEPLOYER_ID:-dev1}"
domain_name="${DOMAIN_NAME:-}"
backoffice_domain_name="${BACKOFFICE_DOMAIN_NAME:-}"
namespace_name="${NAMESPACE:-}"
release_name="${RELEASE_NAME:-}"
release_version="${RELEASE_VERSION:-main}"
dockerhub_namespace="${DOCKERHUB_NAMESPACE:-}"

[ -n "$dockerhub_namespace" ] || {
  printf 'Missing DOCKERHUB_NAMESPACE\n' >&2
  exit 1
}

[ -f "$services_file" ] || {
  printf 'Services file not found: %s\n' "$services_file" >&2
  exit 1
}

[ -f "$all_services_file" ] || {
  printf 'Reference services file not found: %s\n' "$all_services_file" >&2
  exit 1
}

if [ "${TAGS_FILE+x}" = "x" ] && [ -n "$tags_file" ] && [ ! -f "$tags_file" ]; then
  printf 'Tags file not found: %s\n' "$tags_file" >&2
  exit 1
fi

if [ -z "$domain_name" ]; then
  if [ "$environment_name" = "developer" ]; then
    domain_name="storefront-${deployer_id}.yas.local"
  else
    domain_name="storefront-${environment_name}.yas.local"
  fi
fi

if [ -z "$backoffice_domain_name" ]; then
  if [ "$environment_name" = "developer" ]; then
    backoffice_domain_name="backoffice-${deployer_id}.yas.local"
  else
    backoffice_domain_name="backoffice-${environment_name}.yas.local"
  fi
fi

if [ -z "$namespace_name" ]; then
  if [ "$environment_name" = "developer" ]; then
    namespace_name="yas-user-${deployer_id}"
  else
    namespace_name="yas-${environment_name}"
  fi
fi

if [ -z "$release_name" ]; then
  if [ "$environment_name" = "developer" ]; then
    release_name="yas-${deployer_id}"
  else
    release_name="yas-${environment_name}"
  fi
fi

mkdir -p "$(dirname "$output_file")"

if [ -f "$tags_file" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$tags_file"
  set +a
fi

selected_services_file="$(mktemp "${TMPDIR:-/tmp}/yas-selected-services.XXXXXX")"
trap 'rm -f "$selected_services_file"' EXIT INT TERM
iter_catalog_services "$services_file" | while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
  printf '%s|%s|%s|%s|%s|%s|%s\n' "$service" "$path" "$dockerfile" "$port" "$expose" "${node_port:-}" "${workload_type:-backend}" >> "$selected_services_file"
done

cat > "$output_file" <<EOF
global:
  environment: ${environment_name}
  namespace: ${namespace_name}
  domainName: ${domain_name}
  releaseName: ${release_name}

EOF

if [ "$environment_name" = "developer" ]; then
  cat >> "$output_file" <<EOF
externalServices:
  identity:
    externalName: identity.yas-dev.svc.cluster.local
  elasticsearch:
    externalName: elasticsearch.yas-dev.svc.cluster.local
  redis:
    externalName: redis.yas-dev.svc.cluster.local

EOF
fi

cat >> "$output_file" <<EOF
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
      if [ "$environment_name" = "developer" ]; then
        printf '%s-%s.yas.local' "$service" "$deployer_id"
      else
        printf '%s-%s.yas.local' "$service" "$environment_name"
      fi
      ;;
  esac
}

developer_env_overrides() {
  service="$1"

  [ "$environment_name" = "developer" ] || return 0

  db_suffix="$(printf '%s' "$deployer_id" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '_')"

  case "$service" in
    cart|order|customer|inventory|tax|media|search|product)
      printf '    env:\n'
      printf '      - name: SPRING_DATASOURCE_URL\n'
      printf '        value: jdbc:postgresql://postgres.yas-dev.svc.cluster.local:5432/%s_%s\n' "$service" "$db_suffix"
      printf '      - name: SPRING_DATASOURCE_USERNAME\n'
      printf '        value: admin\n'
      printf '      - name: SPRING_DATASOURCE_PASSWORD\n'
      printf '        value: admin\n'
      ;;
    storefront-bff|backoffice-bff)
      printf '    env:\n'
      printf '      - name: YAS_IDENTITY_INTERNAL_BASE_URL\n'
      printf '        value: http://identity.yas-dev.svc.cluster.local\n'
      ;;
  esac
}

iter_catalog_services "$all_services_file" | while IFS='|' read -r service path dockerfile port expose node_port workload_type; do

  selected_entry="$(grep "^${service}|" "$selected_services_file" || true)"
  if [ -z "$selected_entry" ]; then
    cat >> "$output_file" <<EOF
  ${service}:
    enabled: false
EOF
    continue
  fi

  printf '%s\n' "$selected_entry" | while IFS='|' read -r selected_service selected_path selected_dockerfile selected_port selected_expose selected_node_port selected_workload_type; do
    tag_var="$(tag_var_name "$selected_service")"
    tag_value="$(printenv "$tag_var" 2>/dev/null || printf '%s' "$release_version")"
    service_type="ClusterIP"

    if [ "$selected_expose" = "true" ]; then
      service_type="NodePort"
    fi

    cat >> "$output_file" <<EOF
  ${selected_service}:
    enabled: true
    workloadType: ${selected_workload_type}
    image:
      repository: ${dockerhub_namespace}/yas-${selected_service}
      tag: ${tag_value}
      pullPolicy: IfNotPresent
    containerPort: ${selected_port}
    service:
      type: ${service_type}
      port: ${selected_port}
EOF

    if [ "${selected_workload_type}" = "backend" ]; then
      cat >> "$output_file" <<EOF
    metricPort: 8090
EOF
      developer_env_overrides "$selected_service" >> "$output_file"
    fi

    if [ "$selected_expose" = "true" ]; then
      cat >> "$output_file" <<EOF
      nodePort: ${selected_node_port:-32080}
    ingress:
      enabled: true
      host: $(ingress_host_for "$selected_service")
EOF
    fi
  done
done

printf 'Generated %s\n' "$output_file"

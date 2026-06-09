#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

DEPLOYER_ID="${DEPLOYER_ID:-dev1}"
DOMAIN_NAME="${DOMAIN_NAME:-storefront-${DEPLOYER_ID}.yas.local}"
BACKOFFICE_DOMAIN_NAME="${BACKOFFICE_DOMAIN_NAME:-backoffice-${DEPLOYER_ID}.yas.local}"
NAMESPACE="${NAMESPACE:-$(namespace_for "$DEPLOYER_ID")}"
RELEASE_NAME="${RELEASE_NAME:-$(release_name_for "$DEPLOYER_ID")}"

ingress_host_for() {
  local service="$1"

  case "$service" in
    storefront)
      printf '%s' "$DOMAIN_NAME"
      ;;
    backoffice)
      printf '%s' "$BACKOFFICE_DOMAIN_NAME"
      ;;
    *)
      printf '%s-%s.yas.local' "$service" "$DEPLOYER_ID"
      ;;
  esac
}

iter_services | while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
  [[ "$expose" == "true" ]] || continue

  resolved_node_port="${node_port:-}"
  if kubectl get svc -n "$NAMESPACE" "${RELEASE_NAME}-${service}" >/dev/null 2>&1; then
    actual_node_port="$(kubectl get svc -n "$NAMESPACE" "${RELEASE_NAME}-${service}" -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')"
    if [[ -n "$actual_node_port" ]]; then
      resolved_node_port="$actual_node_port"
    fi
  fi

  host="$(ingress_host_for "$service")"
  log "Public endpoint for ${service}: http://${host}:${resolved_node_port}"
done

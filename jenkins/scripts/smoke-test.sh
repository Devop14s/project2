#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

DEPLOYER_ID="${DEPLOYER_ID:-dev1}"
DOMAIN_NAME="${DOMAIN_NAME:-storefront-${DEPLOYER_ID}.yas.local}"
BACKOFFICE_DOMAIN_NAME="${BACKOFFICE_DOMAIN_NAME:-backoffice-${DEPLOYER_ID}.yas.local}"
NAMESPACE="${NAMESPACE:-$(namespace_for "$DEPLOYER_ID")}"
RELEASE_NAME="${RELEASE_NAME:-$(release_name_for "$DEPLOYER_ID")}"
public_service_count=0

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

while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
  [[ "$expose" == "true" ]] || continue
  public_service_count=$((public_service_count + 1))

  if ! kubectl get svc -n "$NAMESPACE" "${RELEASE_NAME}-${service}" >/dev/null 2>&1; then
    fail "Missing expected public service: ${RELEASE_NAME}-${service}"
  fi

  resolved_node_port="$(kubectl get svc -n "$NAMESPACE" "${RELEASE_NAME}-${service}" -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')"
  if [[ -z "$resolved_node_port" ]]; then
    resolved_node_port="${node_port:-}"
  fi

  if [[ -z "$resolved_node_port" ]]; then
    fail "Unable to resolve nodePort for public service: ${RELEASE_NAME}-${service}"
  fi

  ready_endpoint="$(kubectl get endpoints -n "$NAMESPACE" "${RELEASE_NAME}-${service}" -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || true)"
  if [[ -z "$ready_endpoint" ]]; then
    log "Warning: no ready endpoints reported yet for ${RELEASE_NAME}-${service}"
  fi

  host="$(ingress_host_for "$service")"
  log "Public endpoint for ${service}: http://${host}:${resolved_node_port}"
done < <(iter_services)

if [[ "$public_service_count" -eq 0 ]]; then
  fail "No public services were defined in ${SERVICES_FILE:-jenkins/services.env}"
fi

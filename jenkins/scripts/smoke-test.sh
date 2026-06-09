#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

DEPLOYER_ID="${DEPLOYER_ID:-dev1}"
ENVIRONMENT="${ENVIRONMENT:-developer}"
DOMAIN_NAME="${DOMAIN_NAME:-}"
BACKOFFICE_DOMAIN_NAME="${BACKOFFICE_DOMAIN_NAME:-}"
NAMESPACE="${NAMESPACE:-$(default_namespace "$ENVIRONMENT" "$DEPLOYER_ID")}"
RELEASE_NAME="${RELEASE_NAME:-$(default_release_name "$ENVIRONMENT" "$DEPLOYER_ID")}"
public_service_count=0
EVIDENCE_ROOT="${EVIDENCE_ROOT:-work/runtime-evidence}"
evidence_dir="${EVIDENCE_ROOT}/${NAMESPACE}/${RELEASE_NAME}"

mkdir -p "$evidence_dir"
: > "${evidence_dir}/public-endpoints.txt"

if [[ -z "$DOMAIN_NAME" ]]; then
  if [[ "$ENVIRONMENT" == "developer" ]]; then
    DOMAIN_NAME="storefront-${DEPLOYER_ID}.yas.local"
  else
    DOMAIN_NAME="storefront-${ENVIRONMENT}.yas.local"
  fi
fi

if [[ -z "$BACKOFFICE_DOMAIN_NAME" ]]; then
  if [[ "$ENVIRONMENT" == "developer" ]]; then
    BACKOFFICE_DOMAIN_NAME="backoffice-${DEPLOYER_ID}.yas.local"
  else
    BACKOFFICE_DOMAIN_NAME="backoffice-${ENVIRONMENT}.yas.local"
  fi
fi

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
      if [[ "$ENVIRONMENT" == "developer" ]]; then
        printf '%s-%s.yas.local' "$service" "$DEPLOYER_ID"
      else
        printf '%s-%s.yas.local' "$service" "$ENVIRONMENT"
      fi
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
  printf 'http://%s:%s\n' "$host" "$resolved_node_port" >> "${evidence_dir}/public-endpoints.txt"
done < <(iter_services)

if [[ "$public_service_count" -eq 0 ]]; then
  fail "No public services were defined in ${SERVICES_FILE:-jenkins/services.env}"
fi

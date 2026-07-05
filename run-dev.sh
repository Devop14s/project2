#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="yas-dev"
MASTER_NODE="${MASTER_NODE:-k3s-master}"

STOREFRONT_HOST="storefront-dev.yas.local"
BACKOFFICE_HOST="backoffice-dev.yas.local"
SWAGGER_HOST="swagger-ui-dev.yas.local"
IDENTITY_HOST="identity"
IDENTITY_PUBLIC_HOST="identity-dev.yas.local"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing command: $1" >&2
    exit 1
  }
}

require_cmd sudo
require_cmd k3s
require_cmd curl

resolve_master_ip() {
  sudo k3s kubectl get node "${MASTER_NODE}" \
    -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}'
}

curl_code() {
  local host="$1"
  local path="$2"
  curl --resolve "${host}:80:${TARGET_IP}" \
    -sS \
    -o /dev/null \
    -w '%{http_code}' \
    "http://${host}${path}"
}

print_result() {
  local label="$1"
  local code="$2"
  shift 2
  local expected=("$@")
  local matched="false"

  for want in "${expected[@]}"; do
    if [ "${code}" = "${want}" ]; then
      matched="true"
      break
    fi
  done

  if [ "${matched}" = "true" ]; then
    echo "PASS  ${label} -> HTTP ${code}"
  else
    echo "FAIL  ${label} -> HTTP ${code} (expected: ${expected[*]})"
  fi
}

TARGET_IP="${TARGET_IP:-$(resolve_master_ip)}"

if [ -z "${TARGET_IP}" ]; then
  echo "Could not resolve master InternalIP from node ${MASTER_NODE}" >&2
  exit 1
fi

echo "Namespace: ${NAMESPACE}"
echo "Master node: ${MASTER_NODE}"
echo "Target IP: ${TARGET_IP}"
echo
echo "Browser hosts entries:"
echo "  ${TARGET_IP} ${STOREFRONT_HOST}"
echo "  ${TARGET_IP} ${BACKOFFICE_HOST}"
echo "  ${TARGET_IP} ${SWAGGER_HOST}"
echo "  ${TARGET_IP} ${IDENTITY_HOST}"
echo "  ${TARGET_IP} ${IDENTITY_PUBLIC_HOST}"
echo
echo "Browser URLs:"
echo "  Storefront UI      -> http://${STOREFRONT_HOST}/"
echo "  Storefront login   -> http://${STOREFRONT_HOST}/oauth2/authorization/keycloak"
echo "  Backoffice UI      -> http://${BACKOFFICE_HOST}/"
echo "  Backoffice login   -> http://${BACKOFFICE_HOST}/login"
echo "  Swagger UI         -> http://${SWAGGER_HOST}/"
echo "  Keycloak public    -> http://${IDENTITY_PUBLIC_HOST}/"
echo "  Storefront health  -> http://${STOREFRONT_HOST}/actuator/health/liveness"
echo "  Backoffice health  -> http://${BACKOFFICE_HOST}/actuator/health/liveness"
echo
echo "Cluster snapshot:"
sudo k3s kubectl -n "${NAMESPACE}" get pods -o wide
echo
echo "HTTP checks:"

print_result "storefront-ui" "$(curl_code "${STOREFRONT_HOST}" "/")" 200
print_result "storefront-login" "$(curl_code "${STOREFRONT_HOST}" "/oauth2/authorization/keycloak")" 302
print_result "storefront-liveness" "$(curl_code "${STOREFRONT_HOST}" "/actuator/health/liveness")" 200
print_result "storefront-readiness" "$(curl_code "${STOREFRONT_HOST}" "/actuator/health/readiness")" 200

print_result "backoffice-ui" "$(curl_code "${BACKOFFICE_HOST}" "/")" 200
print_result "backoffice-login-page" "$(curl_code "${BACKOFFICE_HOST}" "/login")" 200
print_result "backoffice-oauth" "$(curl_code "${BACKOFFICE_HOST}" "/oauth2/authorization/api-client")" 302
print_result "backoffice-liveness" "$(curl_code "${BACKOFFICE_HOST}" "/actuator/health/liveness")" 200
print_result "backoffice-readiness" "$(curl_code "${BACKOFFICE_HOST}" "/actuator/health/readiness")" 200

print_result "swagger-ui" "$(curl_code "${SWAGGER_HOST}" "/")" 200
print_result "identity-public-well-known" "$(curl_code "${IDENTITY_PUBLIC_HOST}" "/realms/Yas/.well-known/openid-configuration")" 200
print_result "identity-short-well-known" "$(curl_code "${IDENTITY_HOST}" "/realms/Yas/.well-known/openid-configuration")" 200

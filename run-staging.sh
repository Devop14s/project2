#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="yas-staging"

declare -a PIDS=()

cleanup() {
  for pid in "${PIDS[@]:-}"; do
    kill "$pid" 2>/dev/null || true
  done
}

trap cleanup EXIT INT TERM

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing command: $1" >&2
    exit 1
  }
}

require_cmd sudo
require_cmd k3s
require_cmd curl

wait_for_port() {
  local port="$1"
  local retries="${2:-20}"

  for _ in $(seq 1 "${retries}"); do
    if curl -fsS -o /dev/null "http://127.0.0.1:${port}" 2>/dev/null; then
      return 0
    fi
    sleep 1
  done

  return 1
}

curl_check() {
  local label="$1"
  local url="$2"

  if curl -fsS -I --max-time 10 "$url" >/dev/null 2>&1 || curl -fsS --max-time 10 "$url" >/dev/null 2>&1; then
    echo "PASS  ${label} -> ${url}"
  else
    echo "FAIL  ${label} -> ${url}"
  fi
}

start_pf() {
  local service="$1"
  local local_port="$2"
  local remote_port="$3"
  local label="$4"

  echo "Starting ${label}: http://127.0.0.1:${local_port} -> svc/${service}:${remote_port}"
  sudo k3s kubectl -n "${NAMESPACE}" port-forward --address 0.0.0.0 "svc/${service}" "${local_port}:${remote_port}" &
  PIDS+=("$!")
}

echo "Namespace: ${NAMESPACE}"
echo "Press Ctrl-C to stop all port-forwards."
echo

start_pf "yas-staging-storefront" "32180" "3000" "storefront-ui"
start_pf "yas-staging-backoffice" "32181" "3000" "backoffice-ui"
start_pf "yas-staging-swagger-ui" "32182" "8080" "swagger-ui"
start_pf "storefront-bff" "32183" "80" "storefront-bff"
start_pf "backoffice-bff" "32184" "80" "backoffice-bff"
start_pf "identity" "32190" "80" "keycloak"

echo
echo "Waiting for local forwards to respond..."
wait_for_port "32180" || true
wait_for_port "32181" || true
wait_for_port "32182" || true
wait_for_port "32183" || true
wait_for_port "32184" || true
wait_for_port "32190" || true

echo
echo "Ready:"
echo "  storefront-ui  -> http://127.0.0.1:32180"
echo "  backoffice-ui  -> http://127.0.0.1:32181"
echo "  swagger-ui     -> http://127.0.0.1:32182"
echo "  storefront-bff -> http://127.0.0.1:32183"
echo "  backoffice-bff -> http://127.0.0.1:32184"
echo "  keycloak       -> http://127.0.0.1:32190"
echo
echo "Login path test:"
echo "  http://127.0.0.1:32183/oauth2/authorization/keycloak"
echo "  http://127.0.0.1:32184/oauth2/authorization/keycloak"
echo

echo "Curl checks:"
curl_check "storefront-ui" "http://127.0.0.1:32180"
curl_check "backoffice-ui" "http://127.0.0.1:32181"
curl_check "swagger-ui" "http://127.0.0.1:32182"
curl_check "storefront-bff" "http://127.0.0.1:32183/actuator/health"
curl_check "backoffice-bff" "http://127.0.0.1:32184/actuator/health"
curl_check "keycloak" "http://127.0.0.1:32190/realms/Yas/.well-known/openid-configuration"
curl_check "storefront-login" "http://127.0.0.1:32183/oauth2/authorization/keycloak"
curl_check "backoffice-login" "http://127.0.0.1:32184/oauth2/authorization/keycloak"
echo

wait

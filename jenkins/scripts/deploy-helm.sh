#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

ENVIRONMENT="${ENVIRONMENT:-developer}"
DEPLOYER_ID="${DEPLOYER_ID:-dev1}"
NAMESPACE="${NAMESPACE:-$(default_namespace "$ENVIRONMENT" "$DEPLOYER_ID")}"
RELEASE_NAME="${RELEASE_NAME:-$(default_release_name "$ENVIRONMENT" "$DEPLOYER_ID")}"
VALUES_FILE="${VALUES_FILE:-work/generated-values.yaml}"
HELM_TIMEOUT="${HELM_TIMEOUT:-10m}"

[[ -f "$VALUES_FILE" ]] || fail "Values file not found: ${VALUES_FILE}"

capture_runtime_evidence_on_exit() {
  local exit_code="$1"

  NAMESPACE="$NAMESPACE" \
  RELEASE_NAME="$RELEASE_NAME" \
  VALUES_FILE="$VALUES_FILE" \
  CAPTURE_RUNTIME_REASON="deploy-helm" \
  CAPTURE_RUNTIME_EXIT_CODE="$exit_code" \
  jenkins/scripts/capture-runtime-evidence.sh || true
}

trap 'capture_runtime_evidence_on_exit $?' EXIT

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install "$RELEASE_NAME" helm/yas \
  --namespace "$NAMESPACE" \
  --create-namespace \
  -f helm/yas/values.yaml \
  -f "$VALUES_FILE" \
  --timeout "$HELM_TIMEOUT"

log "Helm install complete. Showing deployed resources:"
kubectl get pods -n "$NAMESPACE"
kubectl get svc -n "$NAMESPACE"

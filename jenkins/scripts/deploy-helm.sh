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

kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$NAMESPACE"

helm upgrade --install "$RELEASE_NAME" helm/yas \
  --namespace "$NAMESPACE" \
  -f helm/yas/values.yaml \
  -f "$VALUES_FILE" \
  --wait \
  --timeout "$HELM_TIMEOUT"

while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
  if kubectl get deployment -n "$NAMESPACE" "${RELEASE_NAME}-${service}" >/dev/null 2>&1; then
    kubectl rollout status -n "$NAMESPACE" "deployment/${RELEASE_NAME}-${service}" --timeout="$HELM_TIMEOUT"
  fi
done < <(iter_services)

kubectl get pods -n "$NAMESPACE"
kubectl get svc -n "$NAMESPACE"

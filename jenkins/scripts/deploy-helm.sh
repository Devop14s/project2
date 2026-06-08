#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

DEPLOYER_ID="${DEPLOYER_ID:-dev1}"
NAMESPACE="${NAMESPACE:-$(namespace_for "$DEPLOYER_ID")}"
RELEASE_NAME="${RELEASE_NAME:-$(release_name_for "$DEPLOYER_ID")}"
VALUES_FILE="${VALUES_FILE:-work/generated-values.yaml}"

[[ -f "$VALUES_FILE" ]] || fail "Values file not found: ${VALUES_FILE}"

kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$NAMESPACE"

helm upgrade --install "$RELEASE_NAME" helm/yas \
  --namespace "$NAMESPACE" \
  -f helm/yas/values.yaml \
  -f "$VALUES_FILE"

kubectl get pods -n "$NAMESPACE"
kubectl get svc -n "$NAMESPACE"


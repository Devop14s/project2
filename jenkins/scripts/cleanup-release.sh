#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

ENVIRONMENT="${ENVIRONMENT:-developer}"
DEPLOYER_ID="${DEPLOYER_ID:-dev1}"
NAMESPACE="${NAMESPACE:-$(default_namespace "$ENVIRONMENT" "$DEPLOYER_ID")}"
RELEASE_NAME="${RELEASE_NAME:-$(default_release_name "$ENVIRONMENT" "$DEPLOYER_ID")}"

helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" || true
kubectl delete namespace "$NAMESPACE" --wait=true || true
kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 && log "Namespace still exists: ${NAMESPACE}" || log "Namespace removed: ${NAMESPACE}"

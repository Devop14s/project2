#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

NAMESPACE="${NAMESPACE:?Missing NAMESPACE}"
RELEASE_NAME="${RELEASE_NAME:?Missing RELEASE_NAME}"
VALUES_FILE="${VALUES_FILE:-}"
EVIDENCE_ROOT="${EVIDENCE_ROOT:-work/runtime-evidence}"
evidence_dir="${EVIDENCE_ROOT}/${NAMESPACE}/${RELEASE_NAME}"

mkdir -p "$evidence_dir"

if [[ -n "$VALUES_FILE" && -f "$VALUES_FILE" ]]; then
  cp "$VALUES_FILE" "${evidence_dir}/values-used.yaml"
fi

{
  printf 'namespace=%s\n' "$NAMESPACE"
  printf 'release_name=%s\n' "$RELEASE_NAME"
  printf 'services_file=%s\n' "$SERVICES_FILE"
  printf 'source_root=%s\n' "$SOURCE_ROOT"
  printf 'source_git_root=%s\n' "$SOURCE_GIT_ROOT"
  printf 'generated_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
} > "${evidence_dir}/runtime-context.env"

helm status "$RELEASE_NAME" -n "$NAMESPACE" > "${evidence_dir}/helm-status.txt"
kubectl get namespace "$NAMESPACE" -o yaml > "${evidence_dir}/namespace.yaml"
kubectl get deployment -n "$NAMESPACE" -o wide > "${evidence_dir}/deployments.txt"
kubectl get pods -n "$NAMESPACE" -o wide > "${evidence_dir}/pods.txt"
kubectl get svc -n "$NAMESPACE" -o wide > "${evidence_dir}/services.txt"
kubectl get endpoints -n "$NAMESPACE" > "${evidence_dir}/endpoints.txt"
kubectl get ingress -n "$NAMESPACE" > "${evidence_dir}/ingress.txt" 2>&1 || true

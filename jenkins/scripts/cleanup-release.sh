#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

ENVIRONMENT="${ENVIRONMENT:-developer}"
DEPLOYER_ID="${DEPLOYER_ID:-dev1}"
NAMESPACE="${NAMESPACE:-$(default_namespace "$ENVIRONMENT" "$DEPLOYER_ID")}"
RELEASE_NAME="${RELEASE_NAME:-$(default_release_name "$ENVIRONMENT" "$DEPLOYER_ID")}"
DELETE_NAMESPACE="${DELETE_NAMESPACE:-}"
ALLOW_SHARED_ENVIRONMENT_CLEANUP="${ALLOW_SHARED_ENVIRONMENT_CLEANUP:-0}"
ALLOW_SHARED_NAMESPACE_DELETE="${ALLOW_SHARED_NAMESPACE_DELETE:-0}"
CLEANUP_EVIDENCE_ROOT="${CLEANUP_EVIDENCE_ROOT:-work/cleanup-evidence}"
evidence_dir="${CLEANUP_EVIDENCE_ROOT}/${NAMESPACE}/${RELEASE_NAME}"

is_reserved_shared_target() {
  [[ "$ENVIRONMENT" == "dev" || "$ENVIRONMENT" == "staging" || "$NAMESPACE" == "yas-dev" || "$NAMESPACE" == "yas-staging" || "$RELEASE_NAME" == "yas-dev" || "$RELEASE_NAME" == "yas-staging" ]]
}

mkdir -p "$evidence_dir"

if [[ -z "$DELETE_NAMESPACE" ]]; then
  if [[ "$ENVIRONMENT" == "developer" ]]; then
    DELETE_NAMESPACE="1"
  else
    DELETE_NAMESPACE="0"
  fi
fi

{
  printf 'environment=%s\n' "$ENVIRONMENT"
  printf 'deployer_id=%s\n' "$DEPLOYER_ID"
  printf 'namespace=%s\n' "$NAMESPACE"
  printf 'release_name=%s\n' "$RELEASE_NAME"
  printf 'delete_namespace=%s\n' "$DELETE_NAMESPACE"
  printf 'allow_shared_environment_cleanup=%s\n' "$ALLOW_SHARED_ENVIRONMENT_CLEANUP"
  printf 'allow_shared_namespace_delete=%s\n' "$ALLOW_SHARED_NAMESPACE_DELETE"
  printf 'shared_target_detected=%s\n' "$([[ "$ENVIRONMENT" == "dev" || "$ENVIRONMENT" == "staging" || "$NAMESPACE" == "yas-dev" || "$NAMESPACE" == "yas-staging" || "$RELEASE_NAME" == "yas-dev" || "$RELEASE_NAME" == "yas-staging" ]] && printf true || printf false)"
  printf 'generated_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
} > "${evidence_dir}/cleanup-context.env"

if is_reserved_shared_target && [[ "$ALLOW_SHARED_ENVIRONMENT_CLEANUP" != "1" ]]; then
  printf 'Refusing cleanup for shared target namespace=%s release=%s environment=%s without ALLOW_SHARED_ENVIRONMENT_CLEANUP=1\n' "$NAMESPACE" "$RELEASE_NAME" "$ENVIRONMENT" | tee "${evidence_dir}/cleanup-refused.txt" >&2
  exit 1
fi

if is_reserved_shared_target && [[ "$DELETE_NAMESPACE" == "1" && "$ALLOW_SHARED_NAMESPACE_DELETE" != "1" ]]; then
  printf 'Refusing namespace deletion for shared target namespace=%s release=%s without ALLOW_SHARED_NAMESPACE_DELETE=1\n' "$NAMESPACE" "$RELEASE_NAME" | tee "${evidence_dir}/cleanup-refused.txt" >&2
  exit 1
fi

if helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" > "${evidence_dir}/helm-uninstall.txt" 2>&1; then
  release_cleanup_status="removed"
else
  release_cleanup_status="not-found-or-error"
fi
printf 'release_cleanup_status=%s\n' "$release_cleanup_status" >> "${evidence_dir}/cleanup-context.env"

if [[ "$DELETE_NAMESPACE" == "1" ]]; then
  if kubectl delete namespace "$NAMESPACE" --wait=true > "${evidence_dir}/namespace-delete.txt" 2>&1; then
    namespace_delete_status="deleted"
  else
    namespace_delete_status="not-found-or-error"
  fi
else
  namespace_delete_status="skipped"
  printf 'Namespace deletion skipped for %s\n' "$NAMESPACE" > "${evidence_dir}/namespace-delete.txt"
fi
printf 'namespace_delete_status=%s\n' "$namespace_delete_status" >> "${evidence_dir}/cleanup-context.env"

if kubectl get namespace "$NAMESPACE" > "${evidence_dir}/namespace-after.txt" 2>&1; then
  log "Namespace still exists: ${NAMESPACE}"
  printf 'namespace_exists_after_cleanup=true\n' >> "${evidence_dir}/cleanup-context.env"
else
  log "Namespace removed: ${NAMESPACE}"
  printf 'namespace_exists_after_cleanup=false\n' >> "${evidence_dir}/cleanup-context.env"
fi

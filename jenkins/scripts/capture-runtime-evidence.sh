#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

NAMESPACE="${NAMESPACE:?Missing NAMESPACE}"
RELEASE_NAME="${RELEASE_NAME:?Missing RELEASE_NAME}"
VALUES_FILE="${VALUES_FILE:-}"
EVIDENCE_ROOT="${EVIDENCE_ROOT:-work/runtime-evidence}"
evidence_dir="${EVIDENCE_ROOT}/${NAMESPACE}/${RELEASE_NAME}"
capture_reason="${CAPTURE_RUNTIME_REASON:-post-deploy}"
capture_exit_code="${CAPTURE_RUNTIME_EXIT_CODE:-0}"

mkdir -p "$evidence_dir"

if [[ -n "$VALUES_FILE" && -f "$VALUES_FILE" ]]; then
  cp "$VALUES_FILE" "${evidence_dir}/values-used.yaml"
fi

: > "${evidence_dir}/copied-artifacts.txt"

copy_optional_artifact() {
  local source_path="$1"
  local target_name="${2:-$(basename "$source_path")}"

  if [[ -f "$source_path" ]]; then
    cp "$source_path" "${evidence_dir}/${target_name}"
    printf '%s\n' "${target_name}" >> "${evidence_dir}/copied-artifacts.txt"
  fi
}

capture_command_output() {
  local output_file="$1"
  shift

  if "$@" > "$output_file" 2>&1; then
    return 0
  fi

  return 1
}

write_namespace_missing_note() {
  local output_file="$1"
  local resource_label="$2"

  printf 'Namespace %s was not found while collecting %s.\n' "$NAMESPACE" "$resource_label" > "$output_file"
}

copy_optional_artifact "work/branch-tags.env"
copy_optional_artifact "work/branch-tag-metadata.json"
copy_optional_artifact "work/built-image-list.txt"
copy_optional_artifact "work/build-metadata.json"
copy_optional_artifact "work/image-list.txt"
copy_optional_artifact "work/image-digests.txt"
copy_optional_artifact "work/image-metadata.json"
copy_optional_artifact "work/verified-image-list.txt"
copy_optional_artifact "work/verify-image-metadata.json"
copy_optional_artifact "work/commit_sha.txt"
copy_optional_artifact "work/commit_short_sha.txt"
copy_optional_artifact "work/commit-metadata.json"

if capture_command_output "${evidence_dir}/helm-status.txt" helm status "$RELEASE_NAME" -n "$NAMESPACE"; then
  helm_status_result="ok"
else
  helm_status_result="missing-or-error"
fi

if capture_command_output "${evidence_dir}/namespace-check.txt" kubectl get namespace "$NAMESPACE"; then
  namespace_exists_after_capture="true"
else
  namespace_exists_after_capture="false"
fi

if [[ "$namespace_exists_after_capture" == "true" ]]; then
  if capture_command_output "${evidence_dir}/namespace.yaml" kubectl get namespace "$NAMESPACE" -o yaml; then
    namespace_yaml_result="ok"
  else
    namespace_yaml_result="error"
  fi

  if capture_command_output "${evidence_dir}/deployments.txt" kubectl get deployment -n "$NAMESPACE" -o wide; then
    deployments_result="ok"
  else
    deployments_result="error"
  fi

  if capture_command_output "${evidence_dir}/pods.txt" kubectl get pods -n "$NAMESPACE" -o wide; then
    pods_result="ok"
  else
    pods_result="error"
  fi

  if capture_command_output "${evidence_dir}/services.txt" kubectl get svc -n "$NAMESPACE" -o wide; then
    services_result="ok"
  else
    services_result="error"
  fi

  if capture_command_output "${evidence_dir}/endpoints.txt" kubectl get endpoints -n "$NAMESPACE"; then
    endpoints_result="ok"
  else
    endpoints_result="error"
  fi

  if capture_command_output "${evidence_dir}/ingress.txt" kubectl get ingress -n "$NAMESPACE"; then
    ingress_result="ok"
  else
    ingress_result="missing-or-error"
  fi
else
  write_namespace_missing_note "${evidence_dir}/namespace.yaml" 'namespace manifest'
  write_namespace_missing_note "${evidence_dir}/deployments.txt" 'deployments'
  write_namespace_missing_note "${evidence_dir}/pods.txt" 'pods'
  write_namespace_missing_note "${evidence_dir}/services.txt" 'services'
  write_namespace_missing_note "${evidence_dir}/endpoints.txt" 'endpoints'
  write_namespace_missing_note "${evidence_dir}/ingress.txt" 'ingress'
  namespace_yaml_result="missing"
  deployments_result="missing"
  pods_result="missing"
  services_result="missing"
  endpoints_result="missing"
  ingress_result="missing"
fi

{
  printf 'namespace=%s\n' "$NAMESPACE"
  printf 'release_name=%s\n' "$RELEASE_NAME"
  printf 'services_file=%s\n' "$SERVICES_FILE"
  printf 'source_root=%s\n' "$SOURCE_ROOT"
  printf 'source_git_root=%s\n' "$SOURCE_GIT_ROOT"
  printf 'capture_reason=%s\n' "$capture_reason"
  printf 'capture_exit_code=%s\n' "$capture_exit_code"
  printf 'helm_status_result=%s\n' "$helm_status_result"
  printf 'namespace_exists_after_capture=%s\n' "$namespace_exists_after_capture"
  printf 'namespace_yaml_result=%s\n' "$namespace_yaml_result"
  printf 'deployments_result=%s\n' "$deployments_result"
  printf 'pods_result=%s\n' "$pods_result"
  printf 'services_result=%s\n' "$services_result"
  printf 'endpoints_result=%s\n' "$endpoints_result"
  printf 'ingress_result=%s\n' "$ingress_result"
  printf 'generated_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
} > "${evidence_dir}/runtime-context.env"

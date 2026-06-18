#!/usr/bin/env sh
set -eu

as_json=0
if [ "${1:-}" = "--json" ]; then
  as_json=1
fi

get_helm_path() {
  if command -v helm >/dev/null 2>&1; then
    command -v helm
    return 0
  fi

  find work/tools -type f -name helm.exe 2>/dev/null | head -n 1 || true
}

emit_result() {
  type="$1"
  name="$2"
  status="$3"
  required="$4"
  detail="$5"

  if [ "$as_json" -eq 1 ]; then
    printf '{"type":"%s","name":"%s","status":"%s","required":%s,"detail":"%s"}\n' \
      "$type" "$name" "$status" "$required" "$(printf '%s' "$detail" | sed 's/"/\\"/g')"
  else
    printf '%-8s %-22s %-8s %s\n' "$type" "$name" "$status" "$detail"
  fi
}

check_tool() {
  name="$1"
  explicit_path="${2:-}"
  resolved_path="$explicit_path"

  if [ -z "$resolved_path" ] && command -v "$name" >/dev/null 2>&1; then
    resolved_path="$(command -v "$name")"
  fi

  if [ -n "$resolved_path" ]; then
    emit_result tool "$name" ok false "$resolved_path"
    return 0
  fi

  emit_result tool "$name" missing false ""
  return 0
}

required_failures=0

run_required_check() {
  name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    emit_result check "$name" ok true ""
  else
    emit_result check "$name" failed true "$*"
    required_failures=1
  fi
}

run_optional_check() {
  name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    emit_result check "$name" ok false ""
  else
    emit_result check "$name" failed false "$*"
  fi
}

if [ "$as_json" -eq 0 ]; then
  printf '%-8s %-22s %-8s %s\n' type name status detail
fi

helm_path="$(get_helm_path)"
check_tool git
check_tool bash
check_tool docker
check_tool kubectl
check_tool helm "$helm_path"

run_required_check docker-daemon docker version
run_required_check kubectl-client kubectl version --client
if [ -n "$helm_path" ]; then
  run_required_check helm-client "$helm_path" version
else
  emit_result check helm-client failed true "helm missing"
  required_failures=1
fi

if [ -n "${DOCKERHUB_NAMESPACE:-}" ]; then
  emit_result check dockerhub-namespace ok false ""
else
  emit_result check dockerhub-namespace failed false "DOCKERHUB_NAMESPACE missing"
fi

if [ -n "${KUBECONFIG:-}" ]; then
  emit_result check kubeconfig-env ok false ""
  run_optional_check cluster-connectivity kubectl get ns
else
  emit_result check kubeconfig-env failed false "KUBECONFIG missing"
  emit_result check cluster-connectivity failed false "KUBECONFIG missing"
fi

if [ "$required_failures" -ne 0 ]; then
  exit 1
fi

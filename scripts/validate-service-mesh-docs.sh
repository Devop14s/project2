#!/usr/bin/env sh
set -eu

plan_file="${1:-docs/service-mesh-test-plan.md}"
results_file="${2:-docs/service-mesh-results.md}"
kiali_file="${3:-mesh/kiali-access.md}"

assert_contains_all() {
  file_path="$1"
  shift
  text="$(cat "$file_path")"
  for token in "$@"; do
    printf '%s' "$text" | grep -F -q "$token" || {
      printf '%s is missing required token %s.\n' "$file_path" "$token" >&2
      exit 1
    }
  done
}

assert_contains_all "$plan_file" \
  'mTLS strict mode' \
  'mesh/peer-authentication.yaml' \
  'Istio proxy' \
  'Retry on HTTP 500' \
  'mesh/destination-rule.yaml' \
  'mesh/virtual-service-retry.yaml' \
  'Allow and deny policy' \
  'mesh/authorization-policy.yaml' \
  'kubectl exec'

assert_contains_all "$results_file" \
  '## Namespace' \
  '## mTLS evidence' \
  '## Retry evidence' \
  '## Authorization evidence' \
  '<link to screenshot or command output>' \
  '<link to logs or screenshot>' \
  '<link to curl output or screenshot>'

assert_contains_all "$kiali_file" \
  'kubectl -n istio-system port-forward svc/kiali 20001:20001' \
  'http://localhost:20001' \
  'target namespace'

printf 'Service-mesh plan, results template, and Kiali access notes are aligned with the current mesh scaffold.\n'

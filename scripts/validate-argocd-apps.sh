#!/usr/bin/env sh
set -eu

dev_app_file="${1:-argocd/app-dev.yaml}"
staging_app_file="${2:-argocd/app-staging.yaml}"

assert_match() {
  file_path="$1"
  pattern="$2"
  message="$3"

  if ! grep -Eq "$pattern" "$file_path"; then
    printf '%s\n' "$message" >&2
    exit 1
  fi
}

test_app_file() {
  file_path="$1"
  expected_name="$2"
  expected_values_file="$3"
  expected_namespace="$4"

  [ -f "$file_path" ] || {
    printf 'ArgoCD application file not found: %s\n' "$file_path" >&2
    exit 1
  }

  assert_match "$file_path" '^kind:[[:space:]]+Application[[:space:]]*$' "ArgoCD application kind mismatch in $file_path"
  assert_match "$file_path" "^[[:space:]]*name:[[:space:]]+${expected_name}[[:space:]]*$" "ArgoCD metadata.name mismatch in $file_path"
  assert_match "$file_path" '^[[:space:]]*namespace:[[:space:]]+argocd[[:space:]]*$' "ArgoCD metadata.namespace should stay argocd in $file_path"
  assert_match "$file_path" '^[[:space:]]*path:[[:space:]]+helm/yas[[:space:]]*$' "ArgoCD source.path should stay helm/yas in $file_path"
  assert_match "$file_path" "^[[:space:]]*-[[:space:]]+${expected_values_file//\//\\/}[[:space:]]*$" "ArgoCD values file mismatch in $file_path"
  assert_match "$file_path" '^[[:space:]]*server:[[:space:]]+https://kubernetes\.default\.svc[[:space:]]*$' "ArgoCD destination.server mismatch in $file_path"
  assert_match "$file_path" "^[[:space:]]*namespace:[[:space:]]+${expected_namespace}[[:space:]]*$" "ArgoCD destination.namespace mismatch in $file_path"
}

test_app_file "$dev_app_file" "yas-dev" "../../argocd/values/dev-values.yaml" "yas-dev"
test_app_file "$staging_app_file" "yas-staging" "../../argocd/values/staging-values.yaml" "yas-staging"

printf 'ArgoCD application manifests are valid: %s and %s\n' "$dev_app_file" "$staging_app_file"

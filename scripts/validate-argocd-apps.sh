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

assert_scalar_value() {
  file_path="$1"
  key_name="$2"
  expected_value="$3"
  message="$4"

  if ! awk -v key_name="$key_name" -v expected_value="$expected_value" '
    {
      line=$0
      sub(/\r$/, "", line)
      if (line ~ "^[[:space:]]*" key_name ":[[:space:]]*") {
        sub("^[[:space:]]*" key_name ":[[:space:]]*", "", line)
        sub(/[[:space:]]+$/, "", line)
        if (line == expected_value) {
          found=1
        }
      }
    }
    END { exit found ? 0 : 1 }
  ' "$file_path"; then
    printf '%s\n' "$message" >&2
    exit 1
  fi
}

assert_list_item() {
  file_path="$1"
  expected_value="$2"
  message="$3"

  if ! awk -v expected_value="$expected_value" '
    {
      line=$0
      sub(/\r$/, "", line)
      if (line ~ "^[[:space:]]*-[[:space:]]*") {
        sub("^[[:space:]]*-[[:space:]]*", "", line)
        sub(/[[:space:]]+$/, "", line)
        if (line == expected_value) {
          found=1
        }
      }
    }
    END { exit found ? 0 : 1 }
  ' "$file_path"; then
    printf '%s\n' "$message" >&2
    exit 1
  fi
}

test_app_file() {
  file_path="$1"
  expected_name="$2"
  expected_repo_url="$3"
  expected_target_revision="$4"
  expected_values_file="$5"
  expected_namespace="$6"
  expected_project="${7:-default}"
  require_automated_sync="${8:-0}"

  [ -f "$file_path" ] || {
    printf 'ArgoCD application file not found: %s\n' "$file_path" >&2
    exit 1
  }

  assert_match "$file_path" '^apiVersion:[[:space:]]+argoproj.io/v1alpha1[[:space:]]*$' "ArgoCD apiVersion mismatch in $file_path"
  assert_match "$file_path" '^kind:[[:space:]]+Application[[:space:]]*$' "ArgoCD application kind mismatch in $file_path"
  assert_match "$file_path" "^[[:space:]]*name:[[:space:]]+${expected_name}[[:space:]]*$" "ArgoCD metadata.name mismatch in $file_path"
  assert_match "$file_path" '^[[:space:]]*namespace:[[:space:]]+argocd[[:space:]]*$' "ArgoCD metadata.namespace should stay argocd in $file_path"
  assert_match "$file_path" "^[[:space:]]*project:[[:space:]]+${expected_project}[[:space:]]*$" "ArgoCD project mismatch in $file_path"
  assert_scalar_value "$file_path" "repoURL" "$expected_repo_url" "ArgoCD repoURL mismatch in $file_path"
  assert_match "$file_path" "^[[:space:]]*targetRevision:[[:space:]]+${expected_target_revision}[[:space:]]*$" "ArgoCD targetRevision mismatch in $file_path"
  assert_match "$file_path" '^[[:space:]]*path:[[:space:]]+helm/yas[[:space:]]*$' "ArgoCD source.path should stay helm/yas in $file_path"
  assert_list_item "$file_path" "$expected_values_file" "ArgoCD values file mismatch in $file_path"
  assert_match "$file_path" '^[[:space:]]*server:[[:space:]]+https://kubernetes\.default\.svc[[:space:]]*$' "ArgoCD destination.server mismatch in $file_path"
  assert_match "$file_path" "^[[:space:]]*namespace:[[:space:]]+${expected_namespace}[[:space:]]*$" "ArgoCD destination.namespace mismatch in $file_path"
  assert_match "$file_path" '^[[:space:]]*-[[:space:]]+CreateNamespace=true[[:space:]]*$' "ArgoCD syncOptions should keep CreateNamespace=true in $file_path"

  if [ "$require_automated_sync" = "1" ]; then
    assert_match "$file_path" '^[[:space:]]*automated:[[:space:]]*$' "ArgoCD automated sync block is missing in $file_path"
    assert_match "$file_path" '^[[:space:]]*prune:[[:space:]]+true[[:space:]]*$' "ArgoCD automated prune=true is missing in $file_path"
    assert_match "$file_path" '^[[:space:]]*selfHeal:[[:space:]]+true[[:space:]]*$' "ArgoCD automated selfHeal=true is missing in $file_path"
  elif grep -Eq '^[[:space:]]*automated:[[:space:]]*$' "$file_path"; then
    printf 'ArgoCD staging manifest should remain manual-sync in %s\n' "$file_path" >&2
    exit 1
  fi
}

test_app_file "$dev_app_file" "yas-dev" "https://github.com/Devop14s/project2.git" "main" "../../argocd/values/dev-values.yaml" "yas-dev" "default" "1"
test_app_file "$staging_app_file" "yas-staging" "https://github.com/Devop14s/project2.git" "main" "../../argocd/values/staging-values.yaml" "yas-staging"

printf 'ArgoCD application manifests are valid: %s and %s\n' "$dev_app_file" "$staging_app_file"

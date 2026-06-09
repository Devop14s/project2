#!/usr/bin/env sh
set -eu

dockerhub_namespace="${1:-demo-ns}"
temp_dir="${TMPDIR:-/tmp}/yas-scaffold-selftest.$$"
repo_root="$(pwd)"

mkdir -p "$temp_dir"
branch_tags_file="${temp_dir}/branch-tags.env"
branch_tag_metadata_file="${temp_dir}/branch-tag-metadata.json"
generated_values_file="${temp_dir}/generated-values.yaml"
dev_generated_values_file="${temp_dir}/dev-generated-values.yaml"
gitops_values_file="${temp_dir}/gitops-values.yaml"
gitops_namespace_values_file="${temp_dir}/gitops-values-with-namespace.yaml"
chart_values_file="${temp_dir}/chart-values.yaml"
manifest_values_file="${temp_dir}/dev-values.yaml"
status_report_file="${temp_dir}/status-report.generated.md"
commit_sha_file="work/commit_sha.txt"
commit_short_sha_file="work/commit_short_sha.txt"
commit_metadata_file="work/commit-metadata.json"
verified_image_list_file="${temp_dir}/verified-image-list.txt"
verify_image_metadata_file="${temp_dir}/verify-image-metadata.json"
verify_image_tags_file="${temp_dir}/verify-image-tags.env"

cleanup() {
  restore_work_file "$commit_sha_file"
  restore_work_file "$commit_short_sha_file"
  restore_work_file "$commit_metadata_file"
  rm -rf "$temp_dir"
}

trap cleanup EXIT INT TERM

cp argocd/values/dev-values.yaml "$manifest_values_file"

service_block_has_enabled_value() {
  file_path="$1"
  service_name="$2"
  expected_value="$3"
  awk -v service="  ${service_name}:" -v expected="    enabled: ${expected_value}" '
    $0 == service { in_block=1; next }
    in_block && /^  [^ ]/ { exit found ? 0 : 1 }
    in_block && $0 == expected { found=1 }
    END { exit found ? 0 : 1 }
  ' "$file_path"
}

files_match_ignoring_crlf() {
  expected_file="$1"
  actual_file="$2"
  normalized_expected_file="${temp_dir}/compare-expected.$$"
  normalized_actual_file="${temp_dir}/compare-actual.$$"
  awk '{ sub(/\r$/, ""); print }' "$expected_file" > "$normalized_expected_file"
  awk '{ sub(/\r$/, ""); print }' "$actual_file" > "$normalized_actual_file"
  cmp -s "$normalized_expected_file" "$normalized_actual_file"
}

backup_work_file() {
  file_path="$1"
  backup_path="${temp_dir}/$(printf '%s' "$file_path" | tr '/\\' '__').bak"
  missing_marker="${backup_path}.missing"

  if [ -f "$file_path" ]; then
    cp "$file_path" "$backup_path"
  else
    : > "$missing_marker"
  fi
}

restore_work_file() {
  file_path="$1"
  backup_path="${temp_dir}/$(printf '%s' "$file_path" | tr '/\\' '__').bak"
  missing_marker="${backup_path}.missing"

  if [ -f "$backup_path" ]; then
    cp "$backup_path" "$file_path"
  elif [ -f "$missing_marker" ]; then
    rm -f "$file_path"
  fi
}

sh scripts/validate-services-catalog.sh >/dev/null
sh scripts/validate-services-catalog.sh jenkins/services.release-baseline.env jenkins/services.env >/dev/null
sh scripts/validate-argocd-apps.sh >/dev/null
sh scripts/validate-chart-values.sh >/dev/null
sh scripts/validate-gitops-values.sh >/dev/null
sh scripts/validate-source-alignment.sh >/dev/null
OUTPUT_FILE="$branch_tags_file" BRANCH_TAG_METADATA_FILE="$branch_tag_metadata_file" sh scripts/resolve-branch-tags.sh >/dev/null
DOCKERHUB_NAMESPACE="$dockerhub_namespace" \
TAGS_FILE="$branch_tags_file" \
OUTPUT_FILE="$generated_values_file" \
sh scripts/generate-values.sh >/dev/null
DOCKERHUB_NAMESPACE="$dockerhub_namespace" \
ENVIRONMENT=dev \
OUTPUT_FILE="$dev_generated_values_file" \
sh scripts/generate-values.sh >/dev/null
TAGS_FILE="$branch_tags_file" \
OUTPUT_FILE="$gitops_values_file" \
ENVIRONMENT=dev \
sh scripts/generate-gitops-values.sh >/dev/null
DOCKERHUB_NAMESPACE="$dockerhub_namespace" \
TAGS_FILE="$branch_tags_file" \
OUTPUT_FILE="$gitops_namespace_values_file" \
ENVIRONMENT=dev \
sh scripts/generate-gitops-values.sh >/dev/null
OUTPUT_FILE="$chart_values_file" \
sh scripts/generate-chart-values.sh >/dev/null
sh scripts/update-manifest-values.sh "$manifest_values_file" test-tag >/dev/null
powershell -ExecutionPolicy Bypass -File scripts/preflight.ps1 -AsJson -SkipCommandChecks >/dev/null
sh scripts/report-status.sh "$status_report_file" --skip-command-checks >/dev/null
if TAGS_FILE="${temp_dir}/missing-tags.env" DOCKERHUB_NAMESPACE="$dockerhub_namespace" OUTPUT_FILE="${temp_dir}/missing-tags-generated-values.yaml" sh scripts/generate-values.sh >/dev/null 2>&1; then
  printf 'generate-values.sh should fail when an explicit TAGS_FILE path is provided but missing.\n' >&2
  exit 1
fi
if TAGS_FILE="${temp_dir}/missing-gitops-tags.env" OUTPUT_FILE="${temp_dir}/missing-tags-gitops-values.yaml" ENVIRONMENT=dev sh scripts/generate-gitops-values.sh >/dev/null 2>&1; then
  printf 'generate-gitops-values.sh should fail when an explicit TAGS_FILE path is provided but missing.\n' >&2
  exit 1
fi
if command -v helm >/dev/null 2>&1; then
  helm lint helm/yas >/dev/null
  helm template yas helm/yas > "${temp_dir}/helm-render.yaml"
fi

grep -q 'TAX_TAG=main' "$branch_tags_file"
grep -q '"service":"storefront"' "$branch_tag_metadata_file"
grep -q '"branch":"main"' "$branch_tag_metadata_file"
grep -q '"tag":"main"' "$branch_tag_metadata_file"
if grep -q 'done < <(' scripts/resolve-branch-tags.sh; then
  printf 'resolve-branch-tags.sh should remain POSIX-safe and must not use process substitution.\n' >&2
  exit 1
fi
grep -q 'Services file not found: %s' scripts/resolve-branch-tags.sh
grep -q 'Source git root not found: %s' scripts/resolve-branch-tags.sh
grep -q 'Source git root is not a git repository: %s' scripts/resolve-branch-tags.sh
grep -q 'repository: demo-ns/yas-storefront-bff' "$generated_values_file"
grep -q 'workloadType: ui' "$generated_values_file"
grep -q 'host: storefront-dev1.yas.local' "$generated_values_file"
grep -q 'host: backoffice-dev1.yas.local' "$generated_values_file"
tracked_shell_modes="$(git ls-files --stage -- 'jenkins/scripts/*.sh' 'scripts/*.sh')"
[ -n "$tracked_shell_modes" ]
printf '%s\n' "$tracked_shell_modes" | awk '$1 != "100755" { exit 1 }'
grep -q "'developer_cleanup'" Jenkinsfile
grep -q 'pipelineRequiresDockerhubNamespace' Jenkinsfile
grep -q "name: 'RELEASE_VERSION'" Jenkinsfile
grep -q "name: 'DEPLOYER_ID'" Jenkinsfile
grep -q "name: 'DELETE_NAMESPACE'" Jenkinsfile
grep -q "name: 'ALLOW_SHARED_ENVIRONMENT_CLEANUP'" Jenkinsfile
grep -q "name: 'ALLOW_SHARED_NAMESPACE_DELETE'" Jenkinsfile
grep -q "name: 'STOREFRONT_BRANCH'" Jenkinsfile
grep -q "PIPELINE_DISPATCH_MODE = 'true'" Jenkinsfile
grep -q "env.RELEASE_VERSION = stagingTarget" Jenkinsfile
grep -q 'env.DOMAIN_NAME = developerBuildTarget' Jenkinsfile
grep -q 'env."${branchParam}" = developerBuildTarget' Jenkinsfile
grep -q "if (env.PIPELINE_DISPATCH_MODE != 'true')" jenkins/pipelines/ci.groovy
grep -q "name: 'DOCKERHUB_NAMESPACE'" jenkins/pipelines/ci.groovy
grep -q 'DOCKERHUB_NAMESPACE must be provided as a parameter or Jenkins job environment value\.' jenkins/pipelines/ci.groovy
grep -q "if (env.PIPELINE_DISPATCH_MODE != 'true')" jenkins/pipelines/developer_build.groovy
grep -q "stage('Docker Login')" jenkins/pipelines/developer_build.groovy
grep -q "stage('Verify Image Tags')" jenkins/pipelines/developer_build.groovy
grep -q "name: 'DOCKERHUB_NAMESPACE'" jenkins/pipelines/developer_build.groovy
grep -q "\[string\]\$PaymentBranch = 'main'" scripts/developer-build-dry-run.ps1
grep -q 'branch-tag-metadata.json' scripts/developer-build-dry-run.ps1
grep -q 'helm/yas' scripts/validate-argocd-apps.sh
grep -q 'staging-values.yaml' scripts/validate-argocd-apps.sh
grep -q 'https://github.com/Devop14s/project2.git' scripts/validate-argocd-apps.sh
grep -q 'CreateNamespace=true' scripts/validate-argocd-apps.sh
grep -q 'selfHeal:\[\[:space:\]\]+true' scripts/validate-argocd-apps.sh
grep -q 'staging manifest should remain manual-sync' scripts/validate-argocd-apps.sh
if grep -q '\${expected_repo_url//' scripts/validate-argocd-apps.sh; then
  printf 'validate-argocd-apps.sh should remain POSIX-safe and must not use bash-only replacement expansion.\n' >&2
  exit 1
fi
grep -q 'assert_scalar_value' scripts/validate-argocd-apps.sh
grep -q 'assert_list_item' scripts/validate-argocd-apps.sh
if grep -q 'set -- \$line' scripts/validate-services-catalog.sh; then
  printf 'validate-services-catalog.sh should preserve empty catalog columns and must not parse lines with set -- $line.\n' >&2
  exit 1
fi
if grep -q 'set -- \$reference_line' scripts/validate-services-catalog.sh; then
  printf 'validate-services-catalog.sh should preserve empty reference-catalog columns and must not parse lines with set -- $reference_line.\n' >&2
  exit 1
fi
if grep -q 'set -- \$selected_entry' scripts/generate-values.sh; then
  printf 'generate-values.sh should preserve empty nodePort columns and must not parse selected entries with set -- $selected_entry.\n' >&2
  exit 1
fi
grep -q 'Services file not found: %s' scripts/generate-values.sh
grep -q 'Tags file not found: %s' scripts/generate-values.sh
grep -q 'Tags file not found: %s' scripts/generate-gitops-values.sh
grep -q "if (env.PIPELINE_DISPATCH_MODE != 'true')" jenkins/pipelines/developer_cleanup.groovy
grep -q "name: 'DELETE_NAMESPACE'" jenkins/pipelines/developer_cleanup.groovy
grep -q "name: 'ALLOW_SHARED_ENVIRONMENT_CLEANUP'" jenkins/pipelines/developer_cleanup.groovy
grep -q "name: 'ALLOW_SHARED_NAMESPACE_DELETE'" jenkins/pipelines/developer_cleanup.groovy
grep -q "if (env.PIPELINE_DISPATCH_MODE != 'true')" jenkins/pipelines/dev_cd.groovy
grep -q "name: 'DOCKERHUB_NAMESPACE'" jenkins/pipelines/dev_cd.groovy
grep -q "stage('Resolve Commit Metadata')" jenkins/pipelines/dev_cd.groovy
grep -q 'jenkins/scripts/write-commit-metadata.sh' jenkins/pipelines/dev_cd.groovy
grep -q "if (env.PIPELINE_DISPATCH_MODE != 'true')" jenkins/pipelines/dev_gitops.groovy
grep -q "name: 'DOCKERHUB_NAMESPACE'" jenkins/pipelines/dev_gitops.groovy
grep -q "stage('Resolve Commit Metadata')" jenkins/pipelines/dev_gitops.groovy
grep -q 'jenkins/scripts/write-commit-metadata.sh' jenkins/pipelines/dev_gitops.groovy
grep -q "if (env.PIPELINE_DISPATCH_MODE != 'true')" jenkins/pipelines/staging_gitops.groovy
grep -q "name: 'DOCKERHUB_NAMESPACE'" jenkins/pipelines/staging_gitops.groovy
grep -q "stage('Resolve Commit Metadata')" jenkins/pipelines/staging_gitops.groovy
grep -q 'jenkins/scripts/write-commit-metadata.sh' jenkins/pipelines/staging_gitops.groovy
grep -q "if (env.PIPELINE_DISPATCH_MODE != 'true')" jenkins/pipelines/staging_release.groovy
grep -q "name: 'DOCKERHUB_NAMESPACE'" jenkins/pipelines/staging_release.groovy
grep -q "stage('Resolve Commit Metadata')" jenkins/pipelines/staging_release.groovy
grep -q 'jenkins/scripts/write-commit-metadata.sh' jenkins/pipelines/staging_release.groovy
grep -q '"commit_sha": "${commit_sha}"' jenkins/scripts/write-commit-metadata.sh
grep -q '"commit_short_sha": "${commit_short_sha}"' jenkins/scripts/write-commit-metadata.sh
grep -q '"generated_at":' jenkins/scripts/write-commit-metadata.sh
grep -q "trap 'write_build_metadata \$?' EXIT" jenkins/scripts/build-images.sh
grep -q 'done < <(iter_services)' jenkins/scripts/build-images.sh
grep -q '"completed": ${build_completed}' jenkins/scripts/build-images.sh
grep -q '"last_image": "${last_image}"' jenkins/scripts/build-images.sh
grep -q 'IMAGE_DIGESTS_FILE="work/image-digests.txt"' jenkins/scripts/push-images.sh
grep -q 'record_repo_digest' jenkins/scripts/push-images.sh
grep -q "trap 'write_push_metadata \$?' EXIT" jenkins/scripts/push-images.sh
grep -q 'done < <(iter_services)' jenkins/scripts/push-images.sh
grep -q '"completed": ${push_completed}' jenkins/scripts/push-images.sh
grep -q '"last_image": "${last_image}"' jenkins/scripts/push-images.sh
grep -q 'docker manifest inspect' jenkins/scripts/verify-image-tags.sh
grep -q 'source "$TAGS_FILE"' jenkins/scripts/verify-image-tags.sh
grep -q 'VERIFY_IMAGE_TAGS_DRY_RUN' jenkins/scripts/verify-image-tags.sh
grep -q 'VERIFIED_IMAGE_LIST_FILE="${VERIFIED_IMAGE_LIST_FILE:-work/verified-image-list.txt}"' jenkins/scripts/verify-image-tags.sh
grep -q "trap 'write_verify_metadata \$?' EXIT" jenkins/scripts/verify-image-tags.sh
grep -q 'done < <(iter_services)' jenkins/scripts/verify-image-tags.sh
grep -q '"completed": ${verify_completed}' jenkins/scripts/verify-image-tags.sh
grep -q '"last_image": "${last_image}"' jenkins/scripts/verify-image-tags.sh
grep -q 'copied-artifacts.txt' jenkins/scripts/capture-runtime-evidence.sh
grep -q 'work/branch-tag-metadata.json' jenkins/scripts/capture-runtime-evidence.sh
grep -q 'work/branch-tag-metadata.json' scripts/report-status.sh
grep -q "printf '%s%s%s\\\\n' '- Service catalog paths and Dockerfiles were verified against the configured source root \`' \"\\\$source_root\" '\`.'" scripts/report-status.sh
grep -q 'work/image-digests.txt' jenkins/scripts/capture-runtime-evidence.sh
grep -q 'work/commit-metadata.json' jenkins/scripts/capture-runtime-evidence.sh
grep -q 'CAPTURE_RUNTIME_EXIT_CODE' jenkins/scripts/capture-runtime-evidence.sh
grep -q 'write_namespace_missing_note' jenkins/scripts/capture-runtime-evidence.sh
grep -q 'capture_runtime_evidence_on_exit' jenkins/scripts/deploy-helm.sh
grep -q 'done < <(iter_services)' jenkins/scripts/deploy-helm.sh
grep -q 'CAPTURE_RUNTIME_REASON="deploy-helm"' jenkins/scripts/deploy-helm.sh
grep -q 'capture_runtime_evidence_on_exit' jenkins/scripts/smoke-test.sh
grep -q 'CAPTURE_RUNTIME_REASON="smoke-test"' jenkins/scripts/smoke-test.sh
grep -q 'ENVIRONMENT="${ENVIRONMENT:-developer}"' jenkins/scripts/cleanup-release.sh
grep -q 'default_namespace "$ENVIRONMENT" "$DEPLOYER_ID"' jenkins/scripts/cleanup-release.sh
grep -q 'ALLOW_SHARED_ENVIRONMENT_CLEANUP="${ALLOW_SHARED_ENVIRONMENT_CLEANUP:-0}"' jenkins/scripts/cleanup-release.sh
grep -q 'DELETE_NAMESPACE="${DELETE_NAMESPACE:-}"' jenkins/scripts/cleanup-release.sh
grep -q 'work/cleanup-evidence' jenkins/scripts/cleanup-release.sh
grep -q 'yas-dev' jenkins/scripts/cleanup-release.sh
grep -q 'yas-staging' jenkins/scripts/cleanup-release.sh
grep -q 'shared_target_detected=' jenkins/scripts/cleanup-release.sh
grep -q 'ALLOW_SHARED_NAMESPACE_DELETE="${ALLOW_SHARED_NAMESPACE_DELETE:-0}"' jenkins/scripts/cleanup-release.sh
grep -q 'Refusing namespace deletion for shared target' jenkins/scripts/cleanup-release.sh
grep -q 'BACKOFFICE_DOMAIN_NAME="${BACKOFFICE_DOMAIN_NAME:-backoffice-${ENVIRONMENT}.yas.local}"' jenkins/scripts/update-manifest-repo.sh
grep -q 'MANIFEST_METADATA_FILE="${MANIFEST_METADATA_FILE:-work/manifest-update-metadata.json}"' jenkins/scripts/update-manifest-repo.sh
grep -q "trap 'write_manifest_metadata \$?' EXIT" jenkins/scripts/update-manifest-repo.sh
grep -q '"manifest_commit_sha": "${manifest_commit_sha}"' jenkins/scripts/update-manifest-repo.sh
grep -q '"last_action": "${last_action}"' jenkins/scripts/update-manifest-repo.sh
grep -q 'docker version' scripts/preflight.sh
grep -q 'present but daemon inaccessible' scripts/preflight.sh
grep -q 'validate-gitops-values' scripts/preflight.ps1
grep -q 'validate-source-alignment' scripts/preflight.sh
if (cd "$temp_dir" && powershell -ExecutionPolicy Bypass -File "${repo_root}/scripts/preflight.ps1" -AsJson >/dev/null 2>&1); then
  printf 'preflight.ps1 -AsJson should fail outside the repo root when scaffold files are missing.\n' >&2
  exit 1
fi
cat > "$verify_image_tags_file" <<'EOF'
PRODUCT_TAG=test-product-tag
STOREFRONT_TAG=main
EOF
VERIFY_IMAGE_TAGS_DRY_RUN=1 \
DOCKERHUB_NAMESPACE="$dockerhub_namespace" \
SERVICE_CATALOG="release-baseline" \
TAGS_FILE="$verify_image_tags_file" \
VERIFIED_IMAGE_LIST_FILE="$verified_image_list_file" \
VERIFY_METADATA_FILE="$verify_image_metadata_file" \
bash jenkins/scripts/verify-image-tags.sh >/dev/null
grep -q 'demo-ns/yas-product:test-product-tag' "$verified_image_list_file"
grep -q 'domainName: storefront-dev.yas.local' "$dev_generated_values_file"
grep -q 'host: backoffice-dev.yas.local' "$dev_generated_values_file"
grep -q 'namespace: yas-dev' "$dev_generated_values_file"
grep -q 'metricPort: 8090' "$generated_values_file"
grep -q 'type: NodePort' "$generated_values_file"
grep -q 'environment: dev' "$gitops_values_file"
grep -q 'payment-paypal:' "$gitops_values_file"
grep -q 'repository: docker.io/example/yas-storefront' "$gitops_values_file"
grep -q 'repository: demo-ns/yas-storefront' "$gitops_namespace_values_file"
grep -q 'repository: docker.io/example/yas-storefront' "$chart_values_file"
grep -q 'host: backoffice.yas.local' "$chart_values_file"
grep -q 'tag: test-tag' "$manifest_values_file"
grep -q '## Runtime Access Notes' "$status_report_file"
grep -q 'Runtime evidence directories now snapshot commit, build, push, and verification artifacts' "$status_report_file"
grep -q 'Commit metadata artifacts now embed the exact commit SHA and short SHA directly in `commit-metadata.json`' "$status_report_file"
grep -q 'GitOps manifest-update helpers now preserve a dedicated metadata artifact' "$status_report_file"
grep -q 'Build, push, and remote-tag verification helpers now preserve partial metadata artifacts' "$status_report_file"
grep -q 'Deploy and smoke-test helpers now capture partial runtime diagnostics' "$status_report_file"
grep -q 'Cleanup helpers now require explicit opt-in for shared targets' "$status_report_file"
DOCKERHUB_NAMESPACE="$dockerhub_namespace" \
SERVICES_FILE="jenkins/services.release-baseline.env" \
OUTPUT_FILE="$generated_values_file" \
sh scripts/generate-values.sh >/dev/null
grep -q '^  inventory:$' "$generated_values_file"
if ! service_block_has_enabled_value "$generated_values_file" "payment" "false"; then
  printf 'Baseline generated values should disable payment.\n' >&2
  exit 1
fi
SERVICE_CATALOG="release-baseline" \
DOCKERHUB_NAMESPACE="$dockerhub_namespace" \
OUTPUT_FILE="$generated_values_file" \
sh scripts/generate-values.sh >/dev/null
if ! service_block_has_enabled_value "$generated_values_file" "payment" "false"; then
  printf 'SERVICE_CATALOG=release-baseline did not switch generate-values.sh to the baseline catalog.\n' >&2
  exit 1
fi
SERVICES_FILE="jenkins/services.release-baseline.env" \
OUTPUT_FILE="$gitops_values_file" \
ENVIRONMENT=dev \
sh scripts/generate-gitops-values.sh >/dev/null
if ! service_block_has_enabled_value "$gitops_values_file" "payment" "false"; then
  printf 'Baseline GitOps values should disable payment.\n' >&2
  exit 1
fi
grep -q 'host: storefront-dev.yas.local' "$gitops_values_file"
grep -q 'host: backoffice-dev.yas.local' "$gitops_values_file"
if ! files_match_ignoring_crlf "$gitops_values_file" "argocd/values/dev-values.yaml"; then
  printf 'Committed argocd/values/dev-values.yaml is out of sync with the baseline generator.\n' >&2
  exit 1
fi
SERVICES_FILE="jenkins/services.release-baseline.env" \
OUTPUT_FILE="$gitops_values_file" \
ENVIRONMENT=staging \
RELEASE_VERSION="v1.0.0" \
sh scripts/generate-gitops-values.sh >/dev/null
grep -q 'host: storefront-staging.yas.local' "$gitops_values_file"
grep -q 'host: backoffice-staging.yas.local' "$gitops_values_file"
if ! files_match_ignoring_crlf "$gitops_values_file" "argocd/values/staging-values.yaml"; then
  printf 'Committed argocd/values/staging-values.yaml is out of sync with the baseline generator.\n' >&2
  exit 1
fi
if [ -f "${temp_dir}/helm-render.yaml" ]; then
  SERVICE_CATALOG="release-baseline" \
  DOCKERHUB_NAMESPACE="$dockerhub_namespace" \
  OUTPUT_FILE="$generated_values_file" \
  sh scripts/generate-values.sh >/dev/null
  helm template yas helm/yas -f helm/yas/values.yaml -f "$generated_values_file" > "${temp_dir}/baseline-helm-render.yaml"
  if grep -q 'name: yas-payment$' "${temp_dir}/baseline-helm-render.yaml"; then
    printf 'Baseline Helm render should not include the payment deployment.\n' >&2
    exit 1
  fi
  if grep -q 'name: yas-sampledata$' "${temp_dir}/baseline-helm-render.yaml"; then
    printf 'Baseline Helm render should not include the sampledata deployment.\n' >&2
    exit 1
  fi
  helm template yas-dev helm/yas -f helm/yas/values.yaml -f argocd/values/dev-values.yaml > "${temp_dir}/gitops-dev-helm-render.yaml"
  grep -q 'host: "storefront-dev.yas.local"' "${temp_dir}/gitops-dev-helm-render.yaml"
  grep -q 'host: "backoffice-dev.yas.local"' "${temp_dir}/gitops-dev-helm-render.yaml"
  helm template yas-staging helm/yas -f helm/yas/values.yaml -f argocd/values/staging-values.yaml > "${temp_dir}/gitops-staging-helm-render.yaml"
  grep -q 'host: "storefront-staging.yas.local"' "${temp_dir}/gitops-staging-helm-render.yaml"
  grep -q 'host: "backoffice-staging.yas.local"' "${temp_dir}/gitops-staging-helm-render.yaml"
  helm template yas-dev helm/yas -f helm/yas/values.yaml -f helm/yas/values-dev.yaml > "${temp_dir}/sample-dev-helm-render.yaml"
  grep -q 'host: "storefront-dev.yas.local"' "${temp_dir}/sample-dev-helm-render.yaml"
  grep -q 'host: "backoffice-dev.yas.local"' "${temp_dir}/sample-dev-helm-render.yaml"
  helm template yas-staging helm/yas -f helm/yas/values.yaml -f helm/yas/values-staging.yaml > "${temp_dir}/sample-staging-helm-render.yaml"
  grep -q 'host: "storefront-staging.yas.local"' "${temp_dir}/sample-staging-helm-render.yaml"
  grep -q 'host: "backoffice-staging.yas.local"' "${temp_dir}/sample-staging-helm-render.yaml"
  helm template yas-dev1 helm/yas -f helm/yas/values.yaml -f helm/yas/values-developer-template.yaml > "${temp_dir}/sample-developer-helm-render.yaml"
  grep -q 'host: "storefront-dev1.yas.local"' "${temp_dir}/sample-developer-helm-render.yaml"
  grep -q 'host: "backoffice-dev1.yas.local"' "${temp_dir}/sample-developer-helm-render.yaml"
  grep -q 'kind: Deployment' "${temp_dir}/helm-render.yaml"
fi

if command -v bash >/dev/null 2>&1; then
  backup_work_file "$commit_sha_file"
  backup_work_file "$commit_short_sha_file"
  backup_work_file "$commit_metadata_file"
  STOREFRONT_BRANCH="" OUTPUT_FILE="${temp_dir}/blank-branch-tags.env" BRANCH_TAG_METADATA_FILE="${temp_dir}/blank-branch-tag-metadata.json" bash scripts/resolve-branch-tags.sh >/dev/null
  grep -q '^STOREFRONT_TAG=main$' "${temp_dir}/blank-branch-tags.env"
  grep -q '"service":"storefront"' "${temp_dir}/blank-branch-tag-metadata.json"
  mkdir -p "${temp_dir}/non-git-source"
  if SERVICES_FILE="${temp_dir}/missing-services.env" OUTPUT_FILE="${temp_dir}/missing-services-branch-tags.env" BRANCH_TAG_METADATA_FILE="${temp_dir}/missing-services-branch-tag-metadata.json" sh scripts/resolve-branch-tags.sh >/dev/null 2>&1; then
    printf 'resolve-branch-tags.sh should fail when the selected services catalog does not exist.\n' >&2
    exit 1
  fi
  if SOURCE_GIT_ROOT="${temp_dir}/non-git-source" OUTPUT_FILE="${temp_dir}/invalid-source-root-branch-tags.env" BRANCH_TAG_METADATA_FILE="${temp_dir}/invalid-source-root-branch-tag-metadata.json" sh scripts/resolve-branch-tags.sh >/dev/null 2>&1; then
    printf 'resolve-branch-tags.sh should fail when SOURCE_GIT_ROOT is not a Git repository.\n' >&2
    exit 1
  fi
  SERVICE_CATALOG="release-baseline" \
  SOURCE_ROOT="yas-source" \
  SOURCE_GIT_ROOT="yas-source" \
  bash jenkins/scripts/write-commit-metadata.sh >/dev/null
  expected_commit_sha="$(git -C yas-source rev-parse HEAD)"
  expected_commit_short_sha="$(git -C yas-source rev-parse --short HEAD)"
  [ "$(cat "$commit_sha_file")" = "$expected_commit_sha" ]
  [ "$(cat "$commit_short_sha_file")" = "$expected_commit_short_sha" ]
  grep -q "\"commit_sha\": \"${expected_commit_sha}\"" "$commit_metadata_file"
  grep -q "\"commit_short_sha\": \"${expected_commit_short_sha}\"" "$commit_metadata_file"
  grep -q '"source_git_root": "yas-source"' "$commit_metadata_file"
  grep -q '"services_file": "jenkins/services.release-baseline.env"' "$commit_metadata_file"
  bash -lc '
    source jenkins/scripts/common.sh
    [ "$(resolve_manifest_branch_ref "" "" "origin/main" "HEAD")" = "main" ]
    [ "$(resolve_manifest_branch_ref "" "" "refs/remotes/origin/feature/demo" "HEAD")" = "feature/demo" ]
    [ "$(resolve_manifest_branch_ref "" "feature/demo" "" "HEAD")" = "feature/demo" ]
    [ "$(resolve_manifest_branch_ref "refs/heads/release/v1.2.3" "" "" "HEAD")" = "release/v1.2.3" ]
  '
fi

printf 'Selftest passed.\n'

#!/usr/bin/env sh
set -eu

dockerhub_namespace="${1:-demo-ns}"
temp_dir="${TMPDIR:-/tmp}/yas-scaffold-selftest.$$"
repo_root="$(pwd)"

mkdir -p "$temp_dir"
branch_tags_file="${temp_dir}/branch-tags.env"
generated_values_file="${temp_dir}/generated-values.yaml"
dev_generated_values_file="${temp_dir}/dev-generated-values.yaml"
gitops_values_file="${temp_dir}/gitops-values.yaml"
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
sh scripts/validate-chart-values.sh >/dev/null
sh scripts/validate-gitops-values.sh >/dev/null
sh scripts/validate-source-alignment.sh >/dev/null
OUTPUT_FILE="$branch_tags_file" sh scripts/resolve-branch-tags.sh >/dev/null
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
OUTPUT_FILE="$chart_values_file" \
sh scripts/generate-chart-values.sh >/dev/null
sh scripts/update-manifest-values.sh "$manifest_values_file" test-tag >/dev/null
powershell -ExecutionPolicy Bypass -File scripts/preflight.ps1 -AsJson -SkipCommandChecks >/dev/null
sh scripts/report-status.sh "$status_report_file" --skip-command-checks >/dev/null
if command -v helm >/dev/null 2>&1; then
  helm lint helm/yas >/dev/null
  helm template yas helm/yas > "${temp_dir}/helm-render.yaml"
fi

grep -q 'TAX_TAG=main' "$branch_tags_file"
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
grep -q "name: 'STOREFRONT_BRANCH'" Jenkinsfile
grep -q "PIPELINE_DISPATCH_MODE = 'true'" Jenkinsfile
grep -q "env.RELEASE_VERSION = stagingTarget" Jenkinsfile
grep -q 'env.DOMAIN_NAME = developerBuildTarget' Jenkinsfile
grep -q 'env."${branchParam}" = developerBuildTarget' Jenkinsfile
grep -q "if (env.PIPELINE_DISPATCH_MODE != 'true')" jenkins/pipelines/ci.groovy
grep -q "if (env.PIPELINE_DISPATCH_MODE != 'true')" jenkins/pipelines/developer_build.groovy
grep -q "stage('Docker Login')" jenkins/pipelines/developer_build.groovy
grep -q "stage('Verify Image Tags')" jenkins/pipelines/developer_build.groovy
grep -q "\[string\]\$PaymentBranch = 'main'" scripts/developer-build-dry-run.ps1
grep -q "if (env.PIPELINE_DISPATCH_MODE != 'true')" jenkins/pipelines/developer_cleanup.groovy
grep -q "if (env.PIPELINE_DISPATCH_MODE != 'true')" jenkins/pipelines/dev_cd.groovy
grep -q "if (env.PIPELINE_DISPATCH_MODE != 'true')" jenkins/pipelines/dev_gitops.groovy
grep -q "if (env.PIPELINE_DISPATCH_MODE != 'true')" jenkins/pipelines/staging_gitops.groovy
grep -q "if (env.PIPELINE_DISPATCH_MODE != 'true')" jenkins/pipelines/staging_release.groovy
grep -q 'IMAGE_DIGESTS_FILE="work/image-digests.txt"' jenkins/scripts/push-images.sh
grep -q 'record_repo_digest' jenkins/scripts/push-images.sh
grep -q 'docker manifest inspect' jenkins/scripts/verify-image-tags.sh
grep -q 'source "$TAGS_FILE"' jenkins/scripts/verify-image-tags.sh
grep -q 'VERIFY_IMAGE_TAGS_DRY_RUN' jenkins/scripts/verify-image-tags.sh
grep -q 'VERIFIED_IMAGE_LIST_FILE="${VERIFIED_IMAGE_LIST_FILE:-work/verified-image-list.txt}"' jenkins/scripts/verify-image-tags.sh
grep -q 'ENVIRONMENT="${ENVIRONMENT:-developer}"' jenkins/scripts/cleanup-release.sh
grep -q 'default_namespace "$ENVIRONMENT" "$DEPLOYER_ID"' jenkins/scripts/cleanup-release.sh
grep -q 'BACKOFFICE_DOMAIN_NAME="${BACKOFFICE_DOMAIN_NAME:-backoffice-${ENVIRONMENT}.yas.local}"' jenkins/scripts/update-manifest-repo.sh
grep -q 'docker version' scripts/preflight.sh
grep -q 'present but daemon inaccessible' scripts/preflight.sh
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
grep -q 'repository: docker.io/example/yas-storefront' "$chart_values_file"
grep -q 'host: backoffice.yas.local' "$chart_values_file"
grep -q 'tag: test-tag' "$manifest_values_file"
grep -q '## Runtime Access Notes' "$status_report_file"
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
  STOREFRONT_BRANCH="" OUTPUT_FILE="${temp_dir}/blank-branch-tags.env" bash scripts/resolve-branch-tags.sh >/dev/null
  grep -q '^STOREFRONT_TAG=main$' "${temp_dir}/blank-branch-tags.env"
  SERVICE_CATALOG="release-baseline" \
  SOURCE_ROOT="yas-source" \
  SOURCE_GIT_ROOT="yas-source" \
  bash jenkins/scripts/write-commit-metadata.sh >/dev/null
  expected_commit_sha="$(git -C yas-source rev-parse HEAD)"
  expected_commit_short_sha="$(git -C yas-source rev-parse --short HEAD)"
  [ "$(cat "$commit_sha_file")" = "$expected_commit_sha" ]
  [ "$(cat "$commit_short_sha_file")" = "$expected_commit_short_sha" ]
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

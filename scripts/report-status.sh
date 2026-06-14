#!/usr/bin/env sh
set -eu

. scripts/catalog.sh
. scripts/source-root.sh

output_file="${1:-work/status-report.generated.md}"
skip_command_checks=0

if [ "${2:-}" = "--skip-command-checks" ] || [ "${1:-}" = "--skip-command-checks" ]; then
  skip_command_checks=1
  if [ "${1:-}" = "--skip-command-checks" ]; then
    output_file="work/status-report.generated.md"
  fi
fi

mkdir -p "$(dirname "$output_file")"

required_files="
README.md
Jenkinsfile
jenkins/README.md
jenkins/services.env
jenkins/services.release-baseline.env
jenkins/pipelines/ci.groovy
jenkins/pipelines/developer_build.groovy
jenkins/pipelines/developer_cleanup.groovy
jenkins/pipelines/dev_cd.groovy
jenkins/pipelines/dev_gitops.groovy
jenkins/pipelines/staging_release.groovy
jenkins/pipelines/staging_gitops.groovy
jenkins/scripts/build-images.sh
jenkins/scripts/capture-runtime-evidence.sh
jenkins/scripts/cleanup-release.sh
jenkins/scripts/common.sh
jenkins/scripts/deploy-helm.sh
jenkins/scripts/docker-login.sh
jenkins/scripts/generate-values.sh
jenkins/scripts/push-images.sh
jenkins/scripts/resolve-branch-tags.sh
jenkins/scripts/smoke-test.sh
jenkins/scripts/update-manifest-repo.sh
jenkins/scripts/verify-image-tags.sh
jenkins/scripts/write-commit-metadata.sh
helm/yas/Chart.yaml
helm/yas/values-dev.yaml
helm/yas/values-staging.yaml
helm/yas/values-developer-template.yaml
helm/yas/values.yaml
docs/status-report.md
argocd/app-dev.yaml
argocd/app-staging.yaml
argocd/values/dev-values.yaml
argocd/values/staging-values.yaml
mesh/authorization-policy.yaml
mesh/destination-rule.yaml
mesh/peer-authentication.yaml
mesh/virtual-service-retry.yaml
scripts/preflight.ps1
scripts/preflight.sh
scripts/developer-build-dry-run.ps1
scripts/developer-build-dry-run.sh
scripts/catalog.ps1
scripts/catalog.sh
scripts/source-root.ps1
scripts/source-root.sh
scripts/selftest.ps1
scripts/selftest.sh
scripts/validate-argocd-apps.ps1
scripts/validate-argocd-apps.sh
scripts/validate-services-catalog.ps1
scripts/validate-services-catalog.sh
scripts/validate-chart-values.ps1
scripts/validate-chart-values.sh
scripts/validate-gitops-values.ps1
scripts/validate-gitops-values.sh
scripts/validate-source-alignment.ps1
scripts/validate-source-alignment.sh
scripts/report-status.ps1
scripts/report-status.sh
scripts/resolve-branch-tags.ps1
scripts/resolve-branch-tags.sh
scripts/generate-values.ps1
scripts/generate-values.sh
scripts/generate-gitops-values.ps1
scripts/generate-gitops-values.sh
scripts/generate-chart-values.ps1
scripts/generate-chart-values.sh
scripts/update-manifest-values.ps1
scripts/update-manifest-values.sh
"

required_commands="
git
kubectl
helm
docker
"

source_root="$(resolve_source_root)"
service_count=0
release_baseline_service_count=0
public_entry_count=0
ui_count=0
backend_count=0
source_aligned=0
storefront_build_verified=0
backoffice_build_verified=0
storefront_bff_build_verified=0
backoffice_bff_build_verified=0
product_build_verified=0
payment_build_verified=0
payment_paypal_build_verified=0
recommendation_build_verified=0
cart_package_verified=0
customer_package_verified=0
location_package_verified=0
media_package_verified=0
promotion_package_verified=0
rating_package_verified=0
tax_package_verified=0
webhook_package_verified=0
inventory_build_verified=0
order_build_verified=0
sampledata_package_verified=0
search_package_verified=0
product_image_verified=0
storefront_image_verified=0
backoffice_image_verified=0
storefront_bff_image_verified=0
backoffice_bff_image_verified=0
payment_image_verified=0
payment_paypal_image_verified=0
recommendation_image_verified=0
cart_image_verified=0
customer_image_verified=0
location_image_verified=0
media_image_verified=0
promotion_image_verified=0
rating_image_verified=0
tax_image_verified=0
webhook_image_verified=0
inventory_image_verified=0
order_image_verified=0
sampledata_image_verified=0
search_image_verified=0
docker_command_available=0
docker_daemon_reachable=0
helm_lint_verified=0
helm_template_verified=0
gitops_values_verified=0
runtime_evidence_provenance_verified=0
self_contained_commit_metadata_verified=0
branch_tag_metadata_verified=0
gitops_manifest_metadata_verified=0
partial_image_metadata_verified=0
failure_safe_runtime_evidence_verified=0
cleanup_guard_verified=0
shared_promotion_commit_metadata_verified=0
normalized_services_file="$(mktemp "${TMPDIR:-/tmp}/yas-report-services.XXXXXX")"
normalized_release_baseline_file="$(mktemp "${TMPDIR:-/tmp}/yas-report-release-baseline.XXXXXX")"
trap 'rm -f "$normalized_services_file" "$normalized_release_baseline_file"' EXIT INT TERM

if [ -f "jenkins/services.env" ]; then
  iter_catalog_services "jenkins/services.env" > "$normalized_services_file"
  while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
    service_count=$((service_count + 1))
    if [ "$expose" = "true" ]; then
      public_entry_count=$((public_entry_count + 1))
    fi
    if [ "$workload_type" = "ui" ]; then
      ui_count=$((ui_count + 1))
    elif [ "$workload_type" = "backend" ]; then
      backend_count=$((backend_count + 1))
    fi
  done < "$normalized_services_file"
fi

if [ -f "jenkins/services.release-baseline.env" ]; then
  iter_catalog_services "jenkins/services.release-baseline.env" > "$normalized_release_baseline_file"
  while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
    release_baseline_service_count=$((release_baseline_service_count + 1))
  done < "$normalized_release_baseline_file"
fi

if [ -d "$source_root" ] && [ -f "jenkins/services.env" ]; then
  if SERVICES_FILE="jenkins/services.env" SOURCE_ROOT="$source_root" sh scripts/validate-source-alignment.sh >/dev/null 2>&1; then
    source_aligned=1
  fi
fi

if [ -d "${source_root}/storefront/.next" ]; then
  storefront_build_verified=1
fi
if [ -d "${source_root}/backoffice/.next" ]; then
  backoffice_build_verified=1
fi
if [ -f "${source_root}/storefront-bff/target/storefront-bff-1.0-SNAPSHOT.jar" ]; then
  storefront_bff_build_verified=1
fi
if [ -f "${source_root}/backoffice-bff/target/backoffice-bff-1.0-SNAPSHOT.jar" ]; then
  backoffice_bff_build_verified=1
fi
if [ -f "${source_root}/product/target/product-1.0-SNAPSHOT.jar" ]; then
  product_build_verified=1
fi
if [ -f "${source_root}/payment/target/payment-1.0-SNAPSHOT.jar" ]; then
  payment_build_verified=1
fi
if [ -f "${source_root}/payment-paypal/target/payment-paypal-1.0-SNAPSHOT.jar" ]; then
  payment_paypal_build_verified=1
fi
if [ -f "${source_root}/recommendation/target/recommendation-1.0-SNAPSHOT.jar" ]; then
  recommendation_build_verified=1
fi
if [ -f "${source_root}/cart/target/cart-1.0-SNAPSHOT.jar" ]; then
  cart_package_verified=1
fi
if [ -f "${source_root}/customer/target/customer-1.0-SNAPSHOT.jar" ]; then
  customer_package_verified=1
fi
if [ -f "${source_root}/location/target/location-1.0-SNAPSHOT.jar" ]; then
  location_package_verified=1
fi
if [ -f "${source_root}/media/target/media-1.0-SNAPSHOT.jar" ]; then
  media_package_verified=1
fi
if [ -f "${source_root}/promotion/target/promotion-1.0-SNAPSHOT.jar" ]; then
  promotion_package_verified=1
fi
if [ -f "${source_root}/rating/target/rating-1.0-SNAPSHOT.jar" ]; then
  rating_package_verified=1
fi
if [ -f "${source_root}/tax/target/tax-1.0-SNAPSHOT.jar" ]; then
  tax_package_verified=1
fi
if [ -f "${source_root}/webhook/target/webhook-1.0-SNAPSHOT.jar" ]; then
  webhook_package_verified=1
fi
if [ -f "${source_root}/inventory/target/inventory-1.0-SNAPSHOT.jar" ]; then
  inventory_build_verified=1
fi
if [ -f "${source_root}/order/target/order-1.0-SNAPSHOT.jar" ]; then
  order_build_verified=1
fi
if [ -f "${source_root}/sampledata/target/sampledata-1.0-SNAPSHOT.jar" ]; then
  sampledata_package_verified=1
fi
if [ -f "${source_root}/search/target/search-1.0-SNAPSHOT.jar" ]; then
  search_package_verified=1
fi
if command -v docker >/dev/null 2>&1; then
  docker_command_available=1
  if docker version >/dev/null 2>&1; then
    docker_daemon_reachable=1
  fi
fi
if [ "$docker_daemon_reachable" -eq 1 ]; then
  if docker image inspect yas-product:codex-verified >/dev/null 2>&1; then
    product_image_verified=1
  fi
  if docker image inspect yas-storefront:codex-verified >/dev/null 2>&1; then
    storefront_image_verified=1
  fi
  if docker image inspect yas-backoffice:codex-verified >/dev/null 2>&1; then
    backoffice_image_verified=1
  fi
  if docker image inspect yas-storefront-bff:codex-verified >/dev/null 2>&1; then
    storefront_bff_image_verified=1
  fi
  if docker image inspect yas-backoffice-bff:codex-verified >/dev/null 2>&1; then
    backoffice_bff_image_verified=1
  fi
  if docker image inspect yas-payment:codex-verified >/dev/null 2>&1; then
    payment_image_verified=1
  fi
  if docker image inspect yas-payment-paypal:codex-verified >/dev/null 2>&1; then
    payment_paypal_image_verified=1
  fi
  if docker image inspect yas-recommendation:codex-verified >/dev/null 2>&1; then
    recommendation_image_verified=1
  fi
  if docker image inspect yas-cart:codex-verified >/dev/null 2>&1; then
    cart_image_verified=1
  fi
  if docker image inspect yas-customer:codex-verified >/dev/null 2>&1; then
    customer_image_verified=1
  fi
  if docker image inspect yas-location:codex-verified >/dev/null 2>&1; then
    location_image_verified=1
  fi
  if docker image inspect yas-media:codex-verified >/dev/null 2>&1; then
    media_image_verified=1
  fi
  if docker image inspect yas-promotion:codex-verified >/dev/null 2>&1; then
    promotion_image_verified=1
  fi
  if docker image inspect yas-rating:codex-verified >/dev/null 2>&1; then
    rating_image_verified=1
  fi
  if docker image inspect yas-tax:codex-verified >/dev/null 2>&1; then
    tax_image_verified=1
  fi
  if docker image inspect yas-webhook:codex-verified >/dev/null 2>&1; then
    webhook_image_verified=1
  fi
  if docker image inspect yas-inventory:codex-verified >/dev/null 2>&1; then
    inventory_image_verified=1
  fi
  if docker image inspect yas-order:codex-verified >/dev/null 2>&1; then
    order_image_verified=1
  fi
  if docker image inspect yas-sampledata:codex-verified >/dev/null 2>&1; then
    sampledata_image_verified=1
  fi
  if docker image inspect yas-search:codex-verified >/dev/null 2>&1; then
    search_image_verified=1
  fi
fi
if command -v helm >/dev/null 2>&1; then
  if helm lint helm/yas >/dev/null 2>&1; then
    helm_lint_verified=1
  fi
  if helm template yas helm/yas >/dev/null 2>&1; then
    helm_template_verified=1
  fi
fi
if [ -f "jenkins/services.release-baseline.env" ] && sh scripts/validate-gitops-values.sh jenkins/services.release-baseline.env >/dev/null 2>&1; then
  gitops_values_verified=1
fi
if grep -q 'copied-artifacts.txt' jenkins/scripts/capture-runtime-evidence.sh 2>/dev/null && \
   grep -q 'branch_tag_metadata_file="${BRANCH_TAG_METADATA_FILE:-work/branch-tag-metadata.json}"' jenkins/scripts/capture-runtime-evidence.sh 2>/dev/null && \
   grep -q 'image_digests_file="${IMAGE_DIGESTS_FILE:-work/image-digests.txt}"' jenkins/scripts/capture-runtime-evidence.sh 2>/dev/null && \
   grep -q 'commit_metadata_file="${COMMIT_METADATA_FILE:-work/commit-metadata.json}"' jenkins/scripts/capture-runtime-evidence.sh 2>/dev/null && \
   grep -q 'manifest_metadata_file="${MANIFEST_METADATA_FILE:-work/manifest-update-metadata.json}"' jenkins/scripts/capture-runtime-evidence.sh 2>/dev/null && \
   grep -q 'copy_optional_artifact "\$manifest_metadata_file" "manifest-update-metadata.json"' jenkins/scripts/capture-runtime-evidence.sh 2>/dev/null; then
  runtime_evidence_provenance_verified=1
fi
if grep -q '"commit_sha": "${commit_sha}"' jenkins/scripts/write-commit-metadata.sh 2>/dev/null && \
   grep -q '"commit_short_sha": "${commit_short_sha}"' jenkins/scripts/write-commit-metadata.sh 2>/dev/null && \
   grep -q '"generated_at":' jenkins/scripts/write-commit-metadata.sh 2>/dev/null; then
  self_contained_commit_metadata_verified=1
fi
if grep -q 'branch-tag-metadata.json' scripts/resolve-branch-tags.sh 2>/dev/null && \
   grep -q '"service":"%s"' scripts/resolve-branch-tags.sh 2>/dev/null && \
   grep -q '"branch":"%s"' scripts/resolve-branch-tags.sh 2>/dev/null; then
  branch_tag_metadata_verified=1
fi
if grep -q 'MANIFEST_METADATA_FILE="${MANIFEST_METADATA_FILE:-work/manifest-update-metadata.json}"' jenkins/scripts/update-manifest-repo.sh 2>/dev/null && \
   grep -q 'write_manifest_metadata' jenkins/scripts/update-manifest-repo.sh 2>/dev/null && \
   grep -q '"manifest_commit_sha": "${manifest_commit_sha}"' jenkins/scripts/update-manifest-repo.sh 2>/dev/null && \
   grep -q '"last_action": "${last_action}"' jenkins/scripts/update-manifest-repo.sh 2>/dev/null; then
  gitops_manifest_metadata_verified=1
fi
if grep -q 'write_build_metadata' jenkins/scripts/build-images.sh 2>/dev/null && \
   grep -q '"completed": ${build_completed}' jenkins/scripts/build-images.sh 2>/dev/null && \
   grep -q 'write_push_metadata' jenkins/scripts/push-images.sh 2>/dev/null && \
   grep -q '"completed": ${push_completed}' jenkins/scripts/push-images.sh 2>/dev/null && \
   grep -q 'write_verify_metadata' jenkins/scripts/verify-image-tags.sh 2>/dev/null && \
   grep -q '"completed": ${verify_completed}' jenkins/scripts/verify-image-tags.sh 2>/dev/null; then
  partial_image_metadata_verified=1
fi
if grep -q 'CAPTURE_RUNTIME_EXIT_CODE' jenkins/scripts/capture-runtime-evidence.sh 2>/dev/null && \
   grep -q 'write_namespace_missing_note' jenkins/scripts/capture-runtime-evidence.sh 2>/dev/null && \
   grep -q 'capture_runtime_evidence_on_exit' jenkins/scripts/deploy-helm.sh 2>/dev/null && \
   grep -q 'capture_runtime_evidence_on_exit' jenkins/scripts/smoke-test.sh 2>/dev/null; then
  failure_safe_runtime_evidence_verified=1
fi
if grep -q 'ALLOW_SHARED_ENVIRONMENT_CLEANUP="${ALLOW_SHARED_ENVIRONMENT_CLEANUP:-0}"' jenkins/scripts/cleanup-release.sh 2>/dev/null && \
   grep -q 'ALLOW_SHARED_NAMESPACE_DELETE="${ALLOW_SHARED_NAMESPACE_DELETE:-0}"' jenkins/scripts/cleanup-release.sh 2>/dev/null && \
   grep -q 'shared_target_detected=' jenkins/scripts/cleanup-release.sh 2>/dev/null; then
  cleanup_guard_verified=1
fi
if grep -q 'jenkins/scripts/write-commit-metadata.sh' jenkins/pipelines/dev_cd.groovy 2>/dev/null && \
   grep -q 'jenkins/scripts/write-commit-metadata.sh' jenkins/pipelines/dev_gitops.groovy 2>/dev/null && \
   grep -q 'jenkins/scripts/write-commit-metadata.sh' jenkins/pipelines/staging_release.groovy 2>/dev/null && \
   grep -q 'jenkins/scripts/write-commit-metadata.sh' jenkins/pipelines/staging_gitops.groovy 2>/dev/null; then
  shared_promotion_commit_metadata_verified=1
fi

{
  printf '# Generated Status Report\n\n'
  printf 'Generated at: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S')"
  printf '## Scaffold Files\n'
  for file in $required_files; do
    if [ -f "$file" ]; then
      status="ok"
    else
      status="missing"
    fi
    printf -- '- `%s`: %s\n' "$file" "$status"
  done
  printf '\n'

  if [ "$skip_command_checks" -eq 0 ]; then
    printf '## Host Commands\n'
    for cmd in $required_commands; do
      if [ "$cmd" = "docker" ]; then
        if [ "$docker_command_available" -eq 0 ]; then
          status="missing"
        elif [ "$docker_daemon_reachable" -eq 1 ]; then
          status="ok"
        else
          status="present but daemon inaccessible"
        fi
      else
        if command -v "$cmd" >/dev/null 2>&1; then
          status="ok"
        else
          status="missing"
        fi
      fi
      printf -- '- `%s`: %s\n' "$cmd" "$status"
    done
    printf '\n'
  fi

  printf '## Service Catalog Summary\n'
  printf -- '- Services in catalog: %s\n' "$service_count"
  printf -- '- Services in release baseline: %s\n' "$release_baseline_service_count"
  printf -- '- Public entrypoints in catalog: %s\n' "$public_entry_count"
  printf -- '- UI workloads in catalog: %s\n' "$ui_count"
  printf -- '- Backend workloads in catalog: %s\n' "$backend_count"
  printf '\n'
  printf '## Verified Locally\n'
  printf '%s\n' '- PowerShell preflight is available.'
  printf '%s\n' '- PowerShell selftest is available.'
  printf '%s\n' '- Cross-platform dry-run helpers exist in both `ps1` and `.sh` form.'
  printf '%s\n' '- Generated values include workload-aware fields such as `workloadType` and backend `metricPort`.'
  printf '%s\n' '- GitOps values generation is available for the full service catalog.'
  printf '%s\n' '- Helm baseline values generation is available from the shared service catalog.'
  if [ -f "jenkins/services.release-baseline.env" ]; then
    printf '%s\n' '- A frozen first-release service catalog exists in `jenkins/services.release-baseline.env`.'
  fi
  if [ "$source_aligned" -eq 1 ]; then
    printf '%s%s%s\n' '- Service catalog paths and Dockerfiles were verified against the configured source root `' "$source_root" '`.'
  fi
  if [ "$storefront_build_verified" -eq 1 ]; then
    printf '%s\n' '- A real `storefront` Next.js production build completed successfully in the cloned source tree.'
  fi
  if [ "$backoffice_build_verified" -eq 1 ]; then
    printf '%s\n' '- A real `backoffice` Next.js production build completed successfully in the cloned source tree.'
  fi
  if [ "$storefront_bff_build_verified" -eq 1 ]; then
    printf '%s\n' '- A real `storefront-bff` Maven build completed successfully and produced a runnable JAR artifact.'
  fi
  if [ "$backoffice_bff_build_verified" -eq 1 ]; then
    printf '%s\n' '- A real `backoffice-bff` Maven verification completed successfully and produced a runnable JAR artifact.'
  fi
  if [ "$product_build_verified" -eq 1 ]; then
    printf '%s\n' '- A real `product` Maven backend build completed successfully and produced a runnable JAR artifact.'
  fi
  if [ "$payment_build_verified" -eq 1 ]; then
    printf '%s\n' '- A real `payment` Maven backend build completed successfully and produced a runnable JAR artifact.'
  fi
  if [ "$payment_paypal_build_verified" -eq 1 ]; then
    printf '%s\n' '- A real `payment-paypal` Maven backend build completed successfully and produced a runnable JAR artifact.'
  fi
  if [ "$recommendation_build_verified" -eq 1 ]; then
    printf '%s\n' '- A real `recommendation` Maven backend build completed successfully and produced a runnable JAR artifact.'
  fi
  if [ "$cart_package_verified" -eq 1 ]; then
    printf '%s\n' '- A packaged `cart` JAR was produced successfully in this workspace using a test-skipped Maven build.'
  fi
  if [ "$customer_package_verified" -eq 1 ]; then
    printf '%s\n' '- A packaged `customer` JAR was produced successfully in this workspace using a test-skipped Maven build.'
  fi
  if [ "$location_package_verified" -eq 1 ]; then
    printf '%s\n' '- A packaged `location` JAR was produced successfully in this workspace using a test-skipped Maven build.'
  fi
  if [ "$media_package_verified" -eq 1 ]; then
    printf '%s\n' '- A packaged `media` JAR was produced successfully in this workspace using a test-skipped Maven build.'
  fi
  if [ "$promotion_package_verified" -eq 1 ]; then
    printf '%s\n' '- A packaged `promotion` JAR was produced successfully in this workspace using a test-skipped Maven build.'
  fi
  if [ "$rating_package_verified" -eq 1 ]; then
    printf '%s\n' '- A packaged `rating` JAR was produced successfully in this workspace using a test-skipped Maven build.'
  fi
  if [ "$tax_package_verified" -eq 1 ]; then
    printf '%s\n' '- A packaged `tax` JAR was produced successfully in this workspace using a test-skipped Maven build.'
  fi
  if [ "$webhook_package_verified" -eq 1 ]; then
    printf '%s\n' '- A packaged `webhook` JAR was produced successfully in this workspace using a test-skipped Maven build.'
  fi
  if [ "$inventory_build_verified" -eq 1 ]; then
    printf '%s\n' '- A real `inventory` Maven backend build completed successfully and produced a runnable JAR artifact.'
  fi
  if [ "$order_build_verified" -eq 1 ]; then
    printf '%s\n' '- A real `order` Maven backend build completed successfully and produced a runnable JAR artifact.'
  fi
  if [ "$sampledata_package_verified" -eq 1 ]; then
    printf '%s\n' '- A packaged `sampledata` JAR was produced successfully in this workspace using a test-skipped Maven build.'
  fi
  if [ "$search_package_verified" -eq 1 ]; then
    printf '%s\n' '- A packaged `search` JAR was produced successfully in this workspace using a test-skipped Maven build.'
  fi
  if [ "$product_image_verified" -eq 1 ]; then
    printf '%s\n' '- A real `product` Docker image build completed successfully in this workspace.'
  fi
  if [ "$storefront_image_verified" -eq 1 ]; then
    printf '%s\n' '- A real `storefront` Docker image build completed successfully in this workspace.'
  fi
  if [ "$backoffice_image_verified" -eq 1 ]; then
    printf '%s\n' '- A real `backoffice` Docker image build completed successfully in this workspace.'
  fi
  if [ "$storefront_bff_image_verified" -eq 1 ]; then
    printf '%s\n' '- A real `storefront-bff` Docker image build completed successfully in this workspace.'
  fi
  if [ "$backoffice_bff_image_verified" -eq 1 ]; then
    printf '%s\n' '- A real `backoffice-bff` Docker image build completed successfully in this workspace.'
  fi
  if [ "$payment_image_verified" -eq 1 ]; then
    printf '%s\n' '- A real `payment` Docker image build completed successfully in this workspace.'
  fi
  if [ "$payment_paypal_image_verified" -eq 1 ]; then
    printf '%s\n' '- A real `payment-paypal` Docker image build completed successfully in this workspace.'
  fi
  if [ "$recommendation_image_verified" -eq 1 ]; then
    printf '%s\n' '- A real `recommendation` Docker image build completed successfully in this workspace.'
  fi
  if [ "$cart_image_verified" -eq 1 ]; then
    printf '%s\n' '- A real `cart` Docker image build completed successfully in this workspace.'
  fi
  if [ "$customer_image_verified" -eq 1 ]; then
    printf '%s\n' '- A real `customer` Docker image build completed successfully in this workspace.'
  fi
  if [ "$location_image_verified" -eq 1 ]; then
    printf '%s\n' '- A real `location` Docker image build completed successfully in this workspace.'
  fi
  if [ "$media_image_verified" -eq 1 ]; then
    printf '%s\n' '- A real `media` Docker image build completed successfully in this workspace.'
  fi
  if [ "$promotion_image_verified" -eq 1 ]; then
    printf '%s\n' '- A real `promotion` Docker image build completed successfully in this workspace.'
  fi
  if [ "$rating_image_verified" -eq 1 ]; then
    printf '%s\n' '- A real `rating` Docker image build completed successfully in this workspace.'
  fi
  if [ "$tax_image_verified" -eq 1 ]; then
    printf '%s\n' '- A real `tax` Docker image build completed successfully in this workspace.'
  fi
  if [ "$webhook_image_verified" -eq 1 ]; then
    printf '%s\n' '- A real `webhook` Docker image build completed successfully in this workspace.'
  fi
  if [ "$inventory_image_verified" -eq 1 ]; then
    printf '%s\n' '- A real `inventory` Docker image build completed successfully in this workspace.'
  fi
  if [ "$order_image_verified" -eq 1 ]; then
    printf '%s\n' '- A real `order` Docker image build completed successfully in this workspace.'
  fi
  if [ "$sampledata_image_verified" -eq 1 ]; then
    printf '%s\n' '- A real `sampledata` Docker image build completed successfully in this workspace.'
  fi
  if [ "$search_image_verified" -eq 1 ]; then
    printf '%s\n' '- A real `search` Docker image build completed successfully in this workspace.'
  fi
  if [ "$helm_lint_verified" -eq 1 ]; then
    printf '%s\n' '- A real Helm chart lint completed successfully against `helm/yas`.'
  fi
  if [ "$helm_template_verified" -eq 1 ]; then
    printf '%s\n' '- A real Helm chart template render completed successfully against `helm/yas`.'
  fi
  if [ "$gitops_values_verified" -eq 1 ]; then
    printf '%s\n' '- The committed GitOps values under `argocd/values/` are in sync with the frozen release baseline generator.'
  fi
  if [ "$shared_promotion_commit_metadata_verified" -eq 1 ]; then
    printf '%s\n' '- Shared `dev` and `staging` promotion flows now record commit metadata so mutable and release-tagged deployments can be traced back to an exact source commit.'
  fi
  if [ "$runtime_evidence_provenance_verified" -eq 1 ]; then
    printf '%s\n' '- Runtime evidence directories now snapshot commit, manifest, build, push, and verification artifacts such as `commit-metadata.json`, `manifest-update-metadata.json`, and `image-digests.txt` per run.'
  fi
  if [ "$self_contained_commit_metadata_verified" -eq 1 ]; then
    printf '%s\n' '- Commit metadata artifacts now embed the exact commit SHA and short SHA directly in `commit-metadata.json`, not only in sidecar text files.'
  fi
  if [ "$branch_tag_metadata_verified" -eq 1 ]; then
    printf '%s\n' '- Branch-tag resolution now emits a dedicated metadata artifact that records both the requested branch override and the resolved image tag for each service.'
  fi
  if [ "$gitops_manifest_metadata_verified" -eq 1 ]; then
    printf '%s\n' '- GitOps manifest-update helpers now preserve a dedicated metadata artifact with branch, commit, push, and no-op state for each attempted overlay update.'
  fi
  if [ "$partial_image_metadata_verified" -eq 1 ]; then
    printf '%s\n' '- Build, push, and remote-tag verification helpers now preserve partial metadata artifacts with completion state and the last attempted image when a run fails mid-stream.'
  fi
  if [ "$failure_safe_runtime_evidence_verified" -eq 1 ]; then
    printf '%s\n' '- Deploy and smoke-test helpers now capture partial runtime diagnostics even when rollout or endpoint verification fails, reducing lost evidence on first-failure runs.'
  fi
  if [ "$cleanup_guard_verified" -eq 1 ]; then
    printf '%s\n' '- Cleanup helpers now require explicit opt-in for shared targets and a second explicit opt-in before deleting shared namespaces.'
  fi
  printf '\n'
  printf '## Runtime Access Notes\n'
  if [ "$docker_command_available" -eq 1 ] && [ "$docker_daemon_reachable" -eq 0 ]; then
    printf '%s\n' '- Docker CLI is installed, but the current execution context cannot reach the Docker daemon; local image verification lines may be incomplete unless this report is run with host Docker access.'
  elif [ "$docker_daemon_reachable" -eq 1 ]; then
    printf '%s\n' '- Docker daemon access was available while generating this report, so local image verification could be checked directly.'
  fi
  printf '\n'
  printf '## Still Blocked In This Workspace\n'
  printf '%s\n' '- The full runtime image set has not been built and pushed from this workspace.'
  printf '%s\n' '- A full upstream-style test pass is still blocked for `sampledata` and `search` in this workspace.'
  printf '%s\n' '- The full upstream-style integration path is still blocked for `cart`, `customer`, `location`, and `tax` because Keycloak Testcontainers does not become healthy reliably on this host.'
  printf '%s\n' '- Real Kubernetes deployment cannot be executed.'
  printf '%s\n' '- Jenkins credentials and webhook integration cannot be verified locally.'
} > "$output_file"

printf 'Generated status report: %s\n' "$output_file"

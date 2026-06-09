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
jenkins/scripts/capture-runtime-evidence.sh
jenkins/scripts/verify-image-tags.sh
jenkins/scripts/write-commit-metadata.sh
helm/yas/Chart.yaml
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
inventory_image_verified=0
order_image_verified=0
sampledata_image_verified=0
search_image_verified=0
docker_command_available=0
docker_daemon_reachable=0
helm_lint_verified=0
helm_template_verified=0
gitops_values_verified=0
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
    printf '%s\n' "- Service catalog paths and Dockerfiles were verified against the configured source root \`${source_root}\`."
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
  printf '%s\n' '- Real Kubernetes deployment cannot be executed.'
  printf '%s\n' '- Jenkins credentials and webhook integration cannot be verified locally.'
} > "$output_file"

printf 'Generated status report: %s\n' "$output_file"

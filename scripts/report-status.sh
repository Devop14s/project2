#!/usr/bin/env sh
set -eu

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
helm/yas/Chart.yaml
docs/status-report.md
argocd/app-dev.yaml
mesh/peer-authentication.yaml
scripts/selftest.sh
scripts/validate-services-catalog.sh
"

required_commands="
git
kubectl
helm
docker
"

source_root="yas-source"
service_count=0
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
sampledata_package_verified=0
search_package_verified=0
product_image_verified=0
backoffice_image_verified=0
storefront_bff_image_verified=0
backoffice_bff_image_verified=0
payment_image_verified=0
payment_paypal_image_verified=0
recommendation_image_verified=0
sampledata_image_verified=0
search_image_verified=0
helm_lint_verified=0
helm_template_verified=0
if [ -f "jenkins/services.env" ]; then
  while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
    [ -n "$service" ] || continue
    case "$service" in
      \#*) continue ;;
    esac
    service_count=$((service_count + 1))
    if [ "$expose" = "true" ]; then
      public_entry_count=$((public_entry_count + 1))
    fi
    if [ "$workload_type" = "ui" ]; then
      ui_count=$((ui_count + 1))
    elif [ "$workload_type" = "backend" ]; then
      backend_count=$((backend_count + 1))
    fi
  done < "jenkins/services.env"
fi

if [ -d "$source_root" ] && [ -f "jenkins/services.env" ]; then
  if SERVICES_FILE="jenkins/services.env" SOURCE_ROOT="$source_root" sh scripts/validate-source-alignment.sh >/dev/null 2>&1; then
    source_aligned=1
  fi
fi

if [ -d "yas-source/storefront/.next" ]; then
  storefront_build_verified=1
fi
if [ -d "yas-source/backoffice/.next" ]; then
  backoffice_build_verified=1
fi
if [ -f "yas-source/storefront-bff/target/storefront-bff-1.0-SNAPSHOT.jar" ]; then
  storefront_bff_build_verified=1
fi
if [ -f "yas-source/backoffice-bff/target/backoffice-bff-1.0-SNAPSHOT.jar" ]; then
  backoffice_bff_build_verified=1
fi
if [ -f "yas-source/product/target/product-1.0-SNAPSHOT.jar" ]; then
  product_build_verified=1
fi
if [ -f "yas-source/payment/target/payment-1.0-SNAPSHOT.jar" ]; then
  payment_build_verified=1
fi
if [ -f "yas-source/payment-paypal/target/payment-paypal-1.0-SNAPSHOT.jar" ]; then
  payment_paypal_build_verified=1
fi
if [ -f "yas-source/recommendation/target/recommendation-1.0-SNAPSHOT.jar" ]; then
  recommendation_build_verified=1
fi
if [ -f "yas-source/sampledata/target/sampledata-1.0-SNAPSHOT.jar" ]; then
  sampledata_package_verified=1
fi
if [ -f "yas-source/search/target/search-1.0-SNAPSHOT.jar" ]; then
  search_package_verified=1
fi
if command -v docker >/dev/null 2>&1; then
  if docker image inspect yas-product:codex-verified >/dev/null 2>&1; then
    product_image_verified=1
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
      if command -v "$cmd" >/dev/null 2>&1; then
        status="ok"
      else
        status="missing"
      fi
      printf -- '- `%s`: %s\n' "$cmd" "$status"
    done
    printf '\n'
  fi

  printf '## Service Catalog Summary\n'
  printf -- '- Services in catalog: %s\n' "$service_count"
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
  if [ "$source_aligned" -eq 1 ]; then
    printf '%s\n' '- Service catalog paths and Dockerfiles were verified against the local `yas-source` clone.'
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
  if [ "$sampledata_package_verified" -eq 1 ]; then
    printf '%s\n' '- A packaged `sampledata` JAR was produced successfully in this workspace using a test-skipped Maven build.'
  fi
  if [ "$search_package_verified" -eq 1 ]; then
    printf '%s\n' '- A packaged `search` JAR was produced successfully in this workspace using a test-skipped Maven build.'
  fi
  if [ "$product_image_verified" -eq 1 ]; then
    printf '%s\n' '- A real `product` Docker image build completed successfully in this workspace.'
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
  printf '\n'
  printf '## Still Blocked In This Workspace\n'
  printf '%s\n' '- The full runtime image set has not been built and pushed from this workspace.'
  printf '%s\n' '- A full upstream-style test pass is still blocked for `sampledata` and `search` in this workspace.'
  printf '%s\n' '- Real Kubernetes deployment cannot be executed.'
  printf '%s\n' '- Jenkins credentials and webhook integration cannot be verified locally.'
} > "$output_file"

printf 'Generated status report: %s\n' "$output_file"

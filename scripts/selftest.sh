#!/usr/bin/env sh
set -eu

dockerhub_namespace="${1:-demo-ns}"
temp_dir="${TMPDIR:-/tmp}/yas-scaffold-selftest.$$"

mkdir -p "$temp_dir"
branch_tags_file="${temp_dir}/branch-tags.env"
generated_values_file="${temp_dir}/generated-values.yaml"
gitops_values_file="${temp_dir}/gitops-values.yaml"
manifest_values_file="${temp_dir}/dev-values.yaml"

cleanup() {
  rm -rf "$temp_dir"
}

trap cleanup EXIT INT TERM

cp argocd/values/dev-values.yaml "$manifest_values_file"

sh scripts/validate-services-catalog.sh >/dev/null
OUTPUT_FILE="$branch_tags_file" sh scripts/resolve-branch-tags.sh >/dev/null
DOCKERHUB_NAMESPACE="$dockerhub_namespace" \
TAGS_FILE="$branch_tags_file" \
OUTPUT_FILE="$generated_values_file" \
sh scripts/generate-values.sh >/dev/null
TAGS_FILE="$branch_tags_file" \
OUTPUT_FILE="$gitops_values_file" \
ENVIRONMENT=dev \
sh scripts/generate-gitops-values.sh >/dev/null
sh scripts/update-manifest-values.sh "$manifest_values_file" test-tag >/dev/null

grep -q 'TAX_TAG=main' "$branch_tags_file"
grep -q 'repository: demo-ns/yas-storefront-bff' "$generated_values_file"
grep -q 'workloadType: ui' "$generated_values_file"
grep -q 'host: storefront-dev1.yas.local' "$generated_values_file"
grep -q 'host: backoffice-dev1.yas.local' "$generated_values_file"
grep -q 'metricPort: 8090' "$generated_values_file"
grep -q 'type: NodePort' "$generated_values_file"
grep -q 'environment: dev' "$gitops_values_file"
grep -q 'payment-paypal:' "$gitops_values_file"
grep -q 'tag: test-tag' "$manifest_values_file"

printf 'Selftest passed.\n'

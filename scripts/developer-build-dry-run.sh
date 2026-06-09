#!/usr/bin/env sh
set -eu

if [ "$#" -lt 1 ]; then
  printf 'Usage: %s <dockerhub-namespace> [output-dir] [service-catalog]\n' "$0" >&2
  exit 1
fi

dockerhub_namespace="$1"
output_dir="${2:-work/dry-run}"
service_catalog="${3:-${SERVICE_CATALOG:-full}}"

deployer_id="${DEPLOYER_ID:-dev1}"
domain_name="${DOMAIN_NAME:-storefront-${deployer_id}.yas.local}"
backoffice_domain_name="${BACKOFFICE_DOMAIN_NAME:-backoffice-${deployer_id}.yas.local}"

mkdir -p "$output_dir"

SERVICE_CATALOG="$service_catalog" \
OUTPUT_FILE="${output_dir}/branch-tags.env" \
BRANCH_TAG_METADATA_FILE="${output_dir}/branch-tag-metadata.json" \
sh scripts/resolve-branch-tags.sh
SERVICE_CATALOG="$service_catalog" \
DOCKERHUB_NAMESPACE="$dockerhub_namespace" \
DEPLOYER_ID="$deployer_id" \
DOMAIN_NAME="$domain_name" \
BACKOFFICE_DOMAIN_NAME="$backoffice_domain_name" \
TAGS_FILE="${output_dir}/branch-tags.env" \
OUTPUT_FILE="${output_dir}/generated-values.yaml" \
sh scripts/generate-values.sh

printf '\nGenerated files:\n'
printf '  %s\n' "${output_dir}/branch-tags.env"
printf '  %s\n' "${output_dir}/branch-tag-metadata.json"
printf '  %s\n' "${output_dir}/generated-values.yaml"

#!/usr/bin/env sh
set -eu

services_file="${1:-jenkins/services.release-baseline.env}"
dev_values_file="${2:-argocd/values/dev-values.yaml}"
staging_values_file="${3:-argocd/values/staging-values.yaml}"
staging_release_version="${STAGING_RELEASE_VERSION:-v1.0.0}"

[ -f "$dev_values_file" ] || {
  printf 'Dev values file not found: %s\n' "$dev_values_file" >&2
  exit 1
}

[ -f "$staging_values_file" ] || {
  printf 'Staging values file not found: %s\n' "$staging_values_file" >&2
  exit 1
}

temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/yas-gitops-values.XXXXXX")"

cleanup() {
  rm -rf "$temp_dir"
}

trap cleanup EXIT INT TERM

SERVICES_FILE="$services_file" \
ENVIRONMENT=dev \
OUTPUT_FILE="${temp_dir}/dev-values.yaml" \
sh scripts/generate-gitops-values.sh >/dev/null

SERVICES_FILE="$services_file" \
ENVIRONMENT=staging \
RELEASE_VERSION="$staging_release_version" \
OUTPUT_FILE="${temp_dir}/staging-values.yaml" \
sh scripts/generate-gitops-values.sh >/dev/null

awk '{ sub(/\r$/, ""); print }' "${temp_dir}/dev-values.yaml" > "${temp_dir}/dev-values.normalized.yaml"
awk '{ sub(/\r$/, ""); print }' "$dev_values_file" > "${temp_dir}/dev-values.committed.normalized.yaml"
if ! cmp -s "${temp_dir}/dev-values.normalized.yaml" "${temp_dir}/dev-values.committed.normalized.yaml"; then
  printf 'GitOps dev values drift detected between %s and %s\n' "$services_file" "$dev_values_file" >&2
  exit 1
fi

awk '{ sub(/\r$/, ""); print }' "${temp_dir}/staging-values.yaml" > "${temp_dir}/staging-values.normalized.yaml"
awk '{ sub(/\r$/, ""); print }' "$staging_values_file" > "${temp_dir}/staging-values.committed.normalized.yaml"
if ! cmp -s "${temp_dir}/staging-values.normalized.yaml" "${temp_dir}/staging-values.committed.normalized.yaml"; then
  printf 'GitOps staging values drift detected between %s and %s\n' "$services_file" "$staging_values_file" >&2
  exit 1
fi

printf 'GitOps values are in sync: %s and %s\n' "$dev_values_file" "$staging_values_file"

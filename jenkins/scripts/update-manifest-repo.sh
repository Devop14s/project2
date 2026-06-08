#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

VALUES_FILE="${VALUES_FILE:?Missing VALUES_FILE}"
TAG="${RELEASE_VERSION:-main}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
TAGS_FILE="${TAGS_FILE:-}"
NAMESPACE_NAME="${NAMESPACE_NAME:-yas-${ENVIRONMENT}}"
DOMAIN_NAME="${DOMAIN_NAME:-storefront-${ENVIRONMENT}.yas.local}"

[[ -f "$VALUES_FILE" ]] || fail "Values file not found: ${VALUES_FILE}"
SERVICES_FILE="${SERVICES_FILE:-jenkins/services.env}" \
TAGS_FILE="${TAGS_FILE}" \
OUTPUT_FILE="${VALUES_FILE}" \
ENVIRONMENT="${ENVIRONMENT}" \
NAMESPACE="${NAMESPACE_NAME}" \
DOMAIN_NAME="${DOMAIN_NAME}" \
RELEASE_VERSION="${TAG}" \
sh scripts/generate-gitops-values.sh

log "Generated ${VALUES_FILE} for ${ENVIRONMENT} with default tag ${TAG}"
log "Commit and push logic must be wired after Git credentials and manifest repo strategy are finalized."

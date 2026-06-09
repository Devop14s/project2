#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

VALUES_FILE="${VALUES_FILE:?Missing VALUES_FILE}"
TAG="${RELEASE_VERSION:-main}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
TAGS_FILE="${TAGS_FILE:-}"
NAMESPACE_NAME="${NAMESPACE_NAME:-yas-${ENVIRONMENT}}"
DOMAIN_NAME="${DOMAIN_NAME:-storefront-${ENVIRONMENT}.yas.local}"
BACKOFFICE_DOMAIN_NAME="${BACKOFFICE_DOMAIN_NAME:-backoffice-${ENVIRONMENT}.yas.local}"
GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-Jenkins Bot}"
GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-jenkins@example.local}"
MANIFEST_COMMIT_MESSAGE="${MANIFEST_COMMIT_MESSAGE:-Update ${ENVIRONMENT} GitOps values for ${TAG}}"
MANIFEST_BRANCH="$(resolve_manifest_branch_ref "${MANIFEST_BRANCH:-}" "${BRANCH_NAME:-}" "${GIT_BRANCH:-}" "$(git rev-parse --abbrev-ref HEAD)")"

[[ -f "$VALUES_FILE" ]] || fail "Values file not found: ${VALUES_FILE}"
if [[ -n "${SERVICES_FILE:-}" ]]; then
  export SERVICES_FILE
fi
TAGS_FILE="${TAGS_FILE}" \
OUTPUT_FILE="${VALUES_FILE}" \
ENVIRONMENT="${ENVIRONMENT}" \
NAMESPACE="${NAMESPACE_NAME}" \
DOMAIN_NAME="${DOMAIN_NAME}" \
BACKOFFICE_DOMAIN_NAME="${BACKOFFICE_DOMAIN_NAME}" \
RELEASE_VERSION="${TAG}" \
sh scripts/generate-gitops-values.sh

if git diff --quiet -- "${VALUES_FILE}"; then
  log "No GitOps changes detected in ${VALUES_FILE}"
  exit 0
fi

if [[ "${MANIFEST_BRANCH}" == "HEAD" ]]; then
  fail "Unable to determine manifest branch. Set MANIFEST_BRANCH, BRANCH_NAME, or GIT_BRANCH."
fi

git config user.name "${GIT_AUTHOR_NAME}"
git config user.email "${GIT_AUTHOR_EMAIL}"
git add "${VALUES_FILE}"
git commit -m "${MANIFEST_COMMIT_MESSAGE}"
git push origin "HEAD:${MANIFEST_BRANCH}"

log "Committed and pushed ${VALUES_FILE} to ${MANIFEST_BRANCH}"

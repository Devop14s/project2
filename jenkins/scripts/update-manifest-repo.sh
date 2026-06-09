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
MANIFEST_METADATA_FILE="${MANIFEST_METADATA_FILE:-work/manifest-update-metadata.json}"
manifest_update_completed=false
manifest_changed=false
manifest_committed=false
manifest_pushed=false
manifest_commit_sha=""
last_action="generate-values"
workspace_commit_before="$(git rev-parse HEAD)"

mkdir -p work

write_manifest_metadata() {
  local exit_code="$1"

  cat > "$MANIFEST_METADATA_FILE" <<EOF
{
  "values_file": "${VALUES_FILE}",
  "tag": "${TAG}",
  "environment": "${ENVIRONMENT}",
  "namespace_name": "${NAMESPACE_NAME}",
  "domain_name": "${DOMAIN_NAME}",
  "backoffice_domain_name": "${BACKOFFICE_DOMAIN_NAME}",
  "services_file": "${SERVICES_FILE}",
  "source_root": "${SOURCE_ROOT}",
  "source_git_root": "${SOURCE_GIT_ROOT}",
  "manifest_branch": "${MANIFEST_BRANCH}",
  "manifest_commit_message": "${MANIFEST_COMMIT_MESSAGE}",
  "workspace_commit_before": "${workspace_commit_before}",
  "manifest_commit_sha": "${manifest_commit_sha}",
  "changed": ${manifest_changed},
  "committed": ${manifest_committed},
  "pushed": ${manifest_pushed},
  "completed": ${manifest_update_completed},
  "last_action": "${last_action}",
  "exit_code": ${exit_code},
  "generated_at": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
}
EOF
}

trap 'write_manifest_metadata $?' EXIT

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
last_action="diff-check"

if git diff --quiet -- "${VALUES_FILE}"; then
  last_action="no-changes"
  manifest_update_completed=true
  log "No GitOps changes detected in ${VALUES_FILE}"
  exit 0
fi
manifest_changed=true
last_action="branch-check"

if [[ "${MANIFEST_BRANCH}" == "HEAD" ]]; then
  fail "Unable to determine manifest branch. Set MANIFEST_BRANCH, BRANCH_NAME, or GIT_BRANCH."
fi

git config user.name "${GIT_AUTHOR_NAME}"
git config user.email "${GIT_AUTHOR_EMAIL}"
git add "${VALUES_FILE}"
last_action="commit"
git commit -m "${MANIFEST_COMMIT_MESSAGE}"
manifest_committed=true
manifest_commit_sha="$(git rev-parse HEAD)"
last_action="push"
git push origin "HEAD:${MANIFEST_BRANCH}"
manifest_pushed=true
manifest_update_completed=true
last_action="done"

log "Committed and pushed ${VALUES_FILE} to ${MANIFEST_BRANCH}"

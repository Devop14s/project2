#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

VALUES_FILE="${VALUES_FILE:?Missing VALUES_FILE}"
TAG="${RELEASE_VERSION:-main}"

[[ -f "$VALUES_FILE" ]] || fail "Values file not found: ${VALUES_FILE}"
scripts/update-manifest-values.sh "$VALUES_FILE" "$TAG"

log "Updated ${VALUES_FILE} with tag ${TAG}"
log "Commit and push logic must be wired after Git credentials and manifest repo strategy are finalized."

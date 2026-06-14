#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

COMMIT_SHA_FILE="${COMMIT_SHA_FILE:-work/commit_sha.txt}"
COMMIT_SHORT_SHA_FILE="${COMMIT_SHORT_SHA_FILE:-work/commit_short_sha.txt}"
COMMIT_METADATA_FILE="${COMMIT_METADATA_FILE:-work/commit-metadata.json}"

mkdir -p work
mkdir -p "$(dirname "$COMMIT_SHA_FILE")"
mkdir -p "$(dirname "$COMMIT_SHORT_SHA_FILE")"
mkdir -p "$(dirname "$COMMIT_METADATA_FILE")"

commit_sha="$(git -C "$SOURCE_GIT_ROOT" rev-parse HEAD)"
commit_short_sha="$(git -C "$SOURCE_GIT_ROOT" rev-parse --short HEAD)"
printf '%s\n' "$commit_sha" > "$COMMIT_SHA_FILE"
printf '%s\n' "$commit_short_sha" > "$COMMIT_SHORT_SHA_FILE"

cat > "$COMMIT_METADATA_FILE" <<EOF
{
  "commit_sha": "${commit_sha}",
  "commit_short_sha": "${commit_short_sha}",
  "source_git_root": "${SOURCE_GIT_ROOT}",
  "source_root": "${SOURCE_ROOT}",
  "services_file": "${SERVICES_FILE}",
  "commit_sha_file": "${COMMIT_SHA_FILE}",
  "commit_short_sha_file": "${COMMIT_SHORT_SHA_FILE}",
  "generated_at": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
}
EOF

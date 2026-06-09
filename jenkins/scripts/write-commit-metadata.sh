#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

mkdir -p work
commit_sha="$(git -C "$SOURCE_GIT_ROOT" rev-parse HEAD)"
commit_short_sha="$(git -C "$SOURCE_GIT_ROOT" rev-parse --short HEAD)"
printf '%s\n' "$commit_sha" > work/commit_sha.txt
printf '%s\n' "$commit_short_sha" > work/commit_short_sha.txt

cat > work/commit-metadata.json <<EOF
{
  "commit_sha": "${commit_sha}",
  "commit_short_sha": "${commit_short_sha}",
  "source_git_root": "${SOURCE_GIT_ROOT}",
  "source_root": "${SOURCE_ROOT}",
  "services_file": "${SERVICES_FILE}",
  "commit_sha_file": "work/commit_sha.txt",
  "commit_short_sha_file": "work/commit_short_sha.txt",
  "generated_at": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
}
EOF

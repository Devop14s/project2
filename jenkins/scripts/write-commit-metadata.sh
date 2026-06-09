#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

mkdir -p work
git -C "$SOURCE_GIT_ROOT" rev-parse HEAD > work/commit_sha.txt
git -C "$SOURCE_GIT_ROOT" rev-parse --short HEAD > work/commit_short_sha.txt

cat > work/commit-metadata.json <<EOF
{
  "source_git_root": "${SOURCE_GIT_ROOT}",
  "source_root": "${SOURCE_ROOT}",
  "services_file": "${SERVICES_FILE}",
  "commit_sha_file": "work/commit_sha.txt",
  "commit_short_sha_file": "work/commit_short_sha.txt"
}
EOF

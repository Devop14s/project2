#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

mkdir -p work
TAG="${RELEASE_VERSION:-$(git -C "$SOURCE_GIT_ROOT" rev-parse HEAD)}"
IMAGE_LIST_FILE="work/image-list.txt"
METADATA_FILE="work/image-metadata.json"

: > "$IMAGE_LIST_FILE"

iter_services | while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
  image="$(image_repo "$service"):${TAG}"
  log "Pushing ${image}"
  docker push "$image"
  printf '%s\n' "$image" >> "$IMAGE_LIST_FILE"
done

cat > "$METADATA_FILE" <<EOF
{
  "tag": "${TAG}",
  "services_file": "${SERVICES_FILE}",
  "source_root": "${SOURCE_ROOT}",
  "source_git_root": "${SOURCE_GIT_ROOT}",
  "generated_at": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
}
EOF

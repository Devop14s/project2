#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

mkdir -p work
TAG="${RELEASE_VERSION:-$(git -C "$SOURCE_GIT_ROOT" rev-parse HEAD)}"
IMAGE_LIST_FILE="work/image-list.txt"
IMAGE_DIGESTS_FILE="work/image-digests.txt"
METADATA_FILE="work/image-metadata.json"
push_completed=false
last_service=""
last_image=""

: > "$IMAGE_LIST_FILE"
: > "$IMAGE_DIGESTS_FILE"

write_push_metadata() {
  local exit_code="$1"

  cat > "$METADATA_FILE" <<EOF
{
  "tag": "${TAG}",
  "services_file": "${SERVICES_FILE}",
  "source_root": "${SOURCE_ROOT}",
  "source_git_root": "${SOURCE_GIT_ROOT}",
  "image_list_file": "${IMAGE_LIST_FILE}",
  "image_digests_file": "${IMAGE_DIGESTS_FILE}",
  "completed": ${push_completed},
  "exit_code": ${exit_code},
  "last_service": "${last_service}",
  "last_image": "${last_image}",
  "generated_at": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
}
EOF
}

trap 'write_push_metadata $?' EXIT

record_repo_digest() {
  local image_repo_name="$1"
  local image_tag="$2"
  local local_image="${image_repo_name}:${image_tag}"
  local repo_digest

  repo_digest="$(docker image inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' "$local_image" 2>/dev/null | grep "^${image_repo_name}@" | head -n 1 || true)"
  if [[ -n "$repo_digest" ]]; then
    printf '%s\n' "$repo_digest" >> "$IMAGE_DIGESTS_FILE"
    return
  fi

  log "Warning: no repo digest was reported locally after push for ${local_image}"
  printf '%s <missing-digest>\n' "$local_image" >> "$IMAGE_DIGESTS_FILE"
}

while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
  repo_name="$(image_repo "$service")"
  image="${repo_name}:${TAG}"
  last_service="$service"
  last_image="$image"
  log "Pushing ${image}"
  docker push "$image"
  printf '%s\n' "$image" >> "$IMAGE_LIST_FILE"
  record_repo_digest "$repo_name" "$TAG"
done < <(iter_services)
push_completed=true

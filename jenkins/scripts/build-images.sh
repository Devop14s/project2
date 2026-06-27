#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

mkdir -p work
TAG="$(resolve_image_tag)"
BUILT_IMAGE_LIST_FILE="${BUILT_IMAGE_LIST_FILE:-work/built-image-list.txt}"
BUILD_METADATA_FILE="${BUILD_METADATA_FILE:-work/build-metadata.json}"
build_completed=false
last_service=""
last_image=""

mkdir -p "$(dirname "$BUILT_IMAGE_LIST_FILE")"
mkdir -p "$(dirname "$BUILD_METADATA_FILE")"
: > "$BUILT_IMAGE_LIST_FILE"

write_build_metadata() {
  local exit_code="$1"

  cat > "$BUILD_METADATA_FILE" <<EOF
{
  "tag": "${TAG}",
  "services_file": "${SERVICES_FILE}",
  "source_root": "${SOURCE_ROOT}",
  "source_git_root": "${SOURCE_GIT_ROOT}",
  "built_image_list_file": "${BUILT_IMAGE_LIST_FILE}",
  "completed": ${build_completed},
  "exit_code": ${exit_code},
  "last_service": "${last_service}",
  "last_image": "${last_image}",
  "generated_at": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
}
EOF
}

trap 'write_build_metadata $?' EXIT

while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
  resolved_path="$(service_source_path "$path")"
  resolved_dockerfile="$(service_source_path "$dockerfile")"
  [[ -f "$resolved_dockerfile" ]] || fail "Dockerfile not found for ${service}: ${resolved_dockerfile}"
  log "Building ${service} with tag ${TAG}"
  last_service="$service"
  last_image="$(image_repo "$service"):${TAG}"
  docker build \
    -t "$last_image" \
    -f "$resolved_dockerfile" \
    "$resolved_path"
  printf '%s\n' "$last_image" >> "$BUILT_IMAGE_LIST_FILE"

done < <(iter_services)
build_completed=true

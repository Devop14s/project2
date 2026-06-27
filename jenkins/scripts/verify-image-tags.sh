#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

mkdir -p work
TAGS_FILE="${TAGS_FILE:-work/branch-tags.env}"
VERIFIED_IMAGE_LIST_FILE="${VERIFIED_IMAGE_LIST_FILE:-work/verified-image-list.txt}"
VERIFY_METADATA_FILE="${VERIFY_METADATA_FILE:-work/verify-image-metadata.json}"
VERIFY_IMAGE_TAGS_DRY_RUN="${VERIFY_IMAGE_TAGS_DRY_RUN:-0}"
verify_completed=false
last_service=""
last_image=""

mkdir -p "$(dirname "$VERIFIED_IMAGE_LIST_FILE")"
mkdir -p "$(dirname "$VERIFY_METADATA_FILE")"
: > "$VERIFIED_IMAGE_LIST_FILE"

write_verify_metadata() {
  local exit_code="$1"

  cat > "$VERIFY_METADATA_FILE" <<EOF
{
  "services_file": "${SERVICES_FILE}",
  "source_root": "${SOURCE_ROOT}",
  "source_git_root": "${SOURCE_GIT_ROOT}",
  "tags_file": "${TAGS_FILE}",
  "verified_image_list_file": "${VERIFIED_IMAGE_LIST_FILE}",
  "completed": ${verify_completed},
  "exit_code": ${exit_code},
  "last_service": "${last_service}",
  "last_image": "${last_image}",
  "generated_at": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
}
EOF
}

trap 'write_verify_metadata $?' EXIT

if [[ -n "${TAGS_FILE:-}" && ! -f "$TAGS_FILE" && -z "${RELEASE_VERSION:-}" ]]; then
  fail "Tags file not found and RELEASE_VERSION not set: ${TAGS_FILE}"
fi

if [[ -f "$TAGS_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$TAGS_FILE"
  set +a
fi

resolve_service_tag() {
  local service="$1"
  local tag_env

  tag_env="$(tag_env_name "$service")"
  if [[ -n "${!tag_env:-}" ]]; then
    printf '%s' "${!tag_env}"
    return
  fi

  printf '%s' "${RELEASE_VERSION:-main}"
}

while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
  repo_name="$(image_repo "$service")"
  tag_value="$(resolve_service_tag "$service")"
  image_ref="${repo_name}:${tag_value}"
  last_service="$service"
  last_image="$image_ref"

  log "Verifying remote image tag ${image_ref}"
  if [[ "$VERIFY_IMAGE_TAGS_DRY_RUN" != "1" ]]; then
    docker manifest inspect "$image_ref" >/dev/null
  fi
  printf '%s\n' "$image_ref" >> "$VERIFIED_IMAGE_LIST_FILE"
done < <(iter_services)
verify_completed=true

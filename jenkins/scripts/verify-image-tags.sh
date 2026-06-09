#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

mkdir -p work
TAGS_FILE="${TAGS_FILE:-work/branch-tags.env}"
VERIFIED_IMAGE_LIST_FILE="${VERIFIED_IMAGE_LIST_FILE:-work/verified-image-list.txt}"
VERIFY_METADATA_FILE="${VERIFY_METADATA_FILE:-work/verify-image-metadata.json}"
VERIFY_IMAGE_TAGS_DRY_RUN="${VERIFY_IMAGE_TAGS_DRY_RUN:-0}"

: > "$VERIFIED_IMAGE_LIST_FILE"

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

iter_services | while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
  repo_name="$(image_repo "$service")"
  tag_value="$(resolve_service_tag "$service")"
  image_ref="${repo_name}:${tag_value}"

  log "Verifying remote image tag ${image_ref}"
  if [[ "$VERIFY_IMAGE_TAGS_DRY_RUN" != "1" ]]; then
    docker manifest inspect "$image_ref" >/dev/null
  fi
  printf '%s\n' "$image_ref" >> "$VERIFIED_IMAGE_LIST_FILE"
done

cat > "$VERIFY_METADATA_FILE" <<EOF
{
  "services_file": "${SERVICES_FILE}",
  "source_root": "${SOURCE_ROOT}",
  "source_git_root": "${SOURCE_GIT_ROOT}",
  "tags_file": "${TAGS_FILE}",
  "verified_image_list_file": "${VERIFIED_IMAGE_LIST_FILE}",
  "generated_at": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
}
EOF

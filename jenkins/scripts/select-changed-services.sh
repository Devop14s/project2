#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

SELECTED_SERVICES_FILE="${SELECTED_SERVICES_FILE:-work/changed-services.env}"
SELECTED_SERVICES_FLAG_FILE="${SELECTED_SERVICES_FLAG_FILE:-work/ci-services-file.txt}"
CHANGED_PATHS_FILE="${CHANGED_PATHS_FILE:-work/changed-paths.txt}"
CHANGED_METADATA_FILE="${CHANGED_METADATA_FILE:-work/changed-services-metadata.json}"
MAIN_BRANCH_NAME="${MAIN_BRANCH_NAME:-main}"

mkdir -p "$(dirname "$SELECTED_SERVICES_FILE")"
: > "$SELECTED_SERVICES_FILE"
: > "$CHANGED_PATHS_FILE"

current_branch="${BRANCH_NAME:-}"
if [[ -z "$current_branch" || "$current_branch" == "HEAD" ]]; then
  current_branch="$(git -C "$SOURCE_GIT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
fi

if [[ "$current_branch" == "$MAIN_BRANCH_NAME" ]]; then
  cp "$SERVICES_FILE" "$SELECTED_SERVICES_FILE"
  printf '%s\n' "$SELECTED_SERVICES_FILE" > "$SELECTED_SERVICES_FLAG_FILE"
  log "Main branch detected; selecting full service catalog: ${SERVICES_FILE}"
  cat > "$CHANGED_METADATA_FILE" <<EOF
{
  "branch": "${current_branch}",
  "mode": "full-main",
  "services_file": "${SELECTED_SERVICES_FILE}",
  "generated_at": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
}
EOF
  exit 0
fi

if ! git -C "$SOURCE_GIT_ROOT" rev-parse --verify "origin/${MAIN_BRANCH_NAME}" >/dev/null 2>&1; then
  git -C "$SOURCE_GIT_ROOT" fetch origin "${MAIN_BRANCH_NAME}:refs/remotes/origin/${MAIN_BRANCH_NAME}" >/dev/null 2>&1 || true
fi

if git -C "$SOURCE_GIT_ROOT" rev-parse --verify "origin/${MAIN_BRANCH_NAME}" >/dev/null 2>&1 && \
   base_ref="$(git -C "$SOURCE_GIT_ROOT" merge-base "origin/${MAIN_BRANCH_NAME}" HEAD 2>/dev/null)"; then
  git -C "$SOURCE_GIT_ROOT" diff --name-only "${base_ref}..HEAD" > "$CHANGED_PATHS_FILE"
else
  log "Warning: origin/${MAIN_BRANCH_NAME} unavailable or unrelated; falling back to HEAD^ diff"
  git -C "$SOURCE_GIT_ROOT" diff --name-only HEAD^..HEAD > "$CHANGED_PATHS_FILE"
fi

selected_tmp="$(mktemp "${TMPDIR:-/tmp}/yas-selected-services.XXXXXX")"
trap 'rm -f "$selected_tmp"' EXIT

while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
  source_root_path="${SOURCE_ROOT#./}"
  source_root_path="${source_root_path%/}"
  source_root_name="$(basename "$source_root_path")"
  if grep -q -E "^${source_root_path}/${path}(/|$)|^${source_root_name}/${path}(/|$)|^${path}(/|$)" "$CHANGED_PATHS_FILE"; then
    printf '%s|%s|%s|%s|%s|%s|%s\n' "$service" "$path" "$dockerfile" "$port" "$expose" "$node_port" "$workload_type" >> "$selected_tmp"
  fi
done < <(iter_services)

if [[ ! -s "$selected_tmp" ]]; then
  log "No service source changes detected; skipping image build/push."
else
  sort -u "$selected_tmp" > "$SELECTED_SERVICES_FILE"
fi

printf '%s\n' "$SELECTED_SERVICES_FILE" > "$SELECTED_SERVICES_FLAG_FILE"
log "Selected services file: ${SELECTED_SERVICES_FILE}"
cat "$SELECTED_SERVICES_FILE" || true

cat > "$CHANGED_METADATA_FILE" <<EOF
{
  "branch": "${current_branch}",
  "mode": "changed-services",
  "source_root": "${SOURCE_ROOT}",
  "source_git_root": "${SOURCE_GIT_ROOT}",
  "services_file": "${SERVICES_FILE}",
  "selected_services_file": "${SELECTED_SERVICES_FILE}",
  "changed_paths_file": "${CHANGED_PATHS_FILE}",
  "generated_at": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
}
EOF

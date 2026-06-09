#!/usr/bin/env sh
set -eu

. scripts/catalog.sh
. scripts/source-root.sh

services_file="$(resolve_services_file)"
source_git_root="$(resolve_source_git_root)"
output_file="${OUTPUT_FILE:-work/branch-tags.env}"
metadata_file="${BRANCH_TAG_METADATA_FILE:-work/branch-tag-metadata.json}"

mkdir -p "$(dirname "$output_file")"
mkdir -p "$(dirname "$metadata_file")"
: > "$output_file"
metadata_entries_file="$(mktemp "${TMPDIR:-/tmp}/yas-branch-tag-entries.XXXXXX")"
trap 'rm -f "$metadata_entries_file"' EXIT INT TERM

branch_var_name() {
  printf '%s_BRANCH' "$(printf '%s' "$1" | tr '[:lower:]-' '[:upper:]_')"
}

tag_var_name() {
  printf '%s_TAG' "$(printf '%s' "$1" | tr '[:lower:]-' '[:upper:]_')"
}

resolve_tag() {
  branch="$1"

  if [ "$branch" = "main" ]; then
    printf 'main'
    return
  fi

  if git -C "$source_git_root" rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
    git -C "$source_git_root" rev-parse "origin/$branch"
    return
  fi

  if git -C "$source_git_root" rev-parse --verify "$branch" >/dev/null 2>&1; then
    git -C "$source_git_root" rev-parse "$branch"
    return
  fi

  printf 'Unable to resolve branch in %s: %s\n' "$source_git_root" "$branch" >&2
  exit 1
}

branch_value_for_service() {
  branch_var="$1"
  branch_value="$(printenv "$branch_var" 2>/dev/null || true)"
  if [ -z "$branch_value" ]; then
    branch_value="main"
  fi
  printf '%s' "$branch_value"
}

entry_count=0
iter_catalog_services "$services_file" | while IFS='|' read -r service path dockerfile port expose node_port workload_type; do

  branch_var="$(branch_var_name "$service")"
  branch_value="$(branch_value_for_service "$branch_var")"
  tag_var="$(tag_var_name "$service")"
  tag_value="$(resolve_tag "$branch_value")"
  printf '%s=%s\n' "$tag_var" "$tag_value" >> "$output_file"
  if [ "$entry_count" -gt 0 ]; then
    printf ',\n' >> "$metadata_entries_file"
  fi
  printf '    {"service":"%s","branch":"%s","tag":"%s"}' "$service" "$branch_value" "$tag_value" >> "$metadata_entries_file"
  entry_count=$((entry_count + 1))
done

cat > "$metadata_file" <<EOF
{
  "services_file": "${services_file}",
  "source_git_root": "${source_git_root}",
  "output_file": "${output_file}",
  "generated_at": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "entries": [
$(cat "$metadata_entries_file")
  ]
}
EOF

printf 'Resolved branch tags into %s\n' "$output_file"

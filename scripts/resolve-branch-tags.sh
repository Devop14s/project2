#!/usr/bin/env sh
set -eu

services_file="${SERVICES_FILE:-jenkins/services.env}"
output_file="${OUTPUT_FILE:-work/branch-tags.env}"

mkdir -p "$(dirname "$output_file")"
: > "$output_file"

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

  if git rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
    git rev-parse "origin/$branch"
    return
  fi

  if git rev-parse --verify "$branch" >/dev/null 2>&1; then
    git rev-parse "$branch"
    return
  fi

  printf 'Unable to resolve branch: %s\n' "$branch" >&2
  exit 1
}

while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
  [ -n "$service" ] || continue
  case "$service" in
    \#*) continue ;;
  esac

  branch_var="$(branch_var_name "$service")"
  branch_value="$(printenv "$branch_var" 2>/dev/null || printf 'main')"
  tag_var="$(tag_var_name "$service")"
  tag_value="$(resolve_tag "$branch_value")"
  printf '%s=%s\n' "$tag_var" "$tag_value" >> "$output_file"
done < "$services_file"

printf 'Resolved branch tags into %s\n' "$output_file"

#!/usr/bin/env bash
set -euo pipefail

source scripts/catalog.sh
source scripts/source-root.sh

SERVICES_FILE="$(resolve_services_file)"
SOURCE_ROOT="$(resolve_source_root)"
SOURCE_GIT_ROOT="$(resolve_source_git_root)"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_env() {
  local name="$1"
  [[ -n "${!name:-}" ]] || fail "Missing env: ${name}"
}

sanitize_name() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr '_' '-' | tr -cd 'a-z0-9-'
}

image_repo() {
  local service="$1"
  require_env DOCKERHUB_NAMESPACE
  printf '%s/yas-%s' "$DOCKERHUB_NAMESPACE" "$service"
}

service_source_path() {
  local relative_path="$1"
  if [[ "$SOURCE_ROOT" == "." ]]; then
    printf '%s' "$relative_path"
  else
    printf '%s/%s' "$SOURCE_ROOT" "$relative_path"
  fi
}

release_name_for() {
  local deployer_id="${1:-dev1}"
  printf 'yas-%s' "$(sanitize_name "$deployer_id")"
}

namespace_for() {
  local deployer_id="${1:-dev1}"
  printf 'yas-user-%s' "$(sanitize_name "$deployer_id")"
}

default_release_name() {
  local environment_name="${1:-developer}"
  local deployer_id="${2:-dev1}"

  if [[ "$environment_name" == "developer" ]]; then
    release_name_for "$deployer_id"
  else
    printf 'yas-%s' "$(sanitize_name "$environment_name")"
  fi
}

default_namespace() {
  local environment_name="${1:-developer}"
  local deployer_id="${2:-dev1}"

  if [[ "$environment_name" == "developer" ]]; then
    namespace_for "$deployer_id"
  else
    printf 'yas-%s' "$(sanitize_name "$environment_name")"
  fi
}

branch_env_name() {
  local service="$1"
  printf '%s_BRANCH' "$(printf '%s' "$service" | tr '[:lower:]-' '[:upper:]_')"
}

tag_env_name() {
  local service="$1"
  printf '%s_TAG' "$(printf '%s' "$service" | tr '[:lower:]-' '[:upper:]_')"
}

resolve_manifest_branch_ref() {
  local explicit_branch="${1:-}"
  local branch_name="${2:-}"
  local git_branch="${3:-}"
  local git_fallback="${4:-}"
  local branch_ref="$explicit_branch"

  if [[ -z "$branch_ref" && -n "$branch_name" ]]; then
    branch_ref="$branch_name"
  fi

  if [[ -z "$branch_ref" && -n "$git_branch" ]]; then
    branch_ref="$git_branch"
  fi

  if [[ -z "$branch_ref" ]]; then
    branch_ref="$git_fallback"
  fi

  if [[ "$branch_ref" == refs/heads/* ]]; then
    branch_ref="${branch_ref#refs/heads/}"
  elif [[ "$branch_ref" == refs/remotes/* ]]; then
    branch_ref="${branch_ref#refs/remotes/}"
    branch_ref="${branch_ref#*/}"
  elif [[ "$branch_ref" == origin/* ]]; then
    branch_ref="${branch_ref#origin/}"
  fi

  printf '%s' "$branch_ref"
}

iter_services() {
  iter_catalog_services "$SERVICES_FILE"
}

#!/usr/bin/env bash
set -euo pipefail

SERVICES_FILE="${SERVICES_FILE:-jenkins/services.env}"

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

release_name_for() {
  local deployer_id="${1:-dev1}"
  printf 'yas-%s' "$(sanitize_name "$deployer_id")"
}

namespace_for() {
  local deployer_id="${1:-dev1}"
  printf 'yas-user-%s' "$(sanitize_name "$deployer_id")"
}

branch_env_name() {
  local service="$1"
  printf '%s_BRANCH' "$(printf '%s' "$service" | tr '[:lower:]-' '[:upper:]_')"
}

tag_env_name() {
  local service="$1"
  printf '%s_TAG' "$(printf '%s' "$service" | tr '[:lower:]-' '[:upper:]_')"
}

iter_services() {
  [[ -f "$SERVICES_FILE" ]] || fail "Missing services file: $SERVICES_FILE"

  while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
    [[ -z "${service}" ]] && continue
    [[ "${service}" == \#* ]] && continue
    printf '%s|%s|%s|%s|%s|%s|%s\n' "$service" "$path" "$dockerfile" "$port" "$expose" "${node_port:-}" "${workload_type:-backend}"
  done < "$SERVICES_FILE"
}

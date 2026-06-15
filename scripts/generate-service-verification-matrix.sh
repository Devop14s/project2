#!/usr/bin/env sh
set -eu

. scripts/catalog.sh
. scripts/source-root.sh

output_file="${1:-work/service-verification.generated.md}"
services_file="$(resolve_services_file)"
source_root="$(resolve_source_root)"
blockers_file="$(mktemp "${TMPDIR:-/tmp}/yas-service-blockers.XXXXXX")"
trap 'rm -f "$blockers_file"' EXIT INT TERM

SERVICE_CATALOG=full SOURCE_ROOT="$source_root" sh scripts/summarize-failsafe-blockers.sh "$blockers_file" >/dev/null 2>&1 || true

is_full_build_verified() {
  case "$1" in
    storefront|backoffice|storefront-bff|backoffice-bff|product|payment|payment-paypal|recommendation|inventory|order) return 0 ;;
    *) return 1 ;;
  esac
}

build_evidence_present() {
  service="$1"
  if [ "$service" = "storefront" ] || [ "$service" = "backoffice" ]; then
    [ -d "${source_root}/${service}/.next" ]
    return
  fi
  [ -f "${source_root}/${service}/target/${service}-1.0-SNAPSHOT.jar" ]
}

build_evidence_kind() {
  service="$1"
  if [ "$service" = "storefront" ] || [ "$service" = "backoffice" ]; then
    printf '.next'
  else
    printf 'jar'
  fi
}

image_verified() {
  service="$1"
  docker version >/dev/null 2>&1 || return 1
  docker image inspect "yas-${service}:codex-verified" >/dev/null 2>&1
}

mkdir -p "$(dirname "$output_file")"
{
  printf '# Service Verification Matrix\n\n'
  printf '%s\n' 'This file is generated from `jenkins/services.env`, local source artifacts under `yas-source/`, local Docker images, and workspace blocker summaries.'
  printf '\n'
  printf '| Service | Workload | Build evidence | Local image | Blocker | Overall status |\n'
  printf '| --- | --- | --- | --- | --- | --- |\n'

  iter_catalog_services "$services_file" | while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
    build_text='no'
    image_text='no'
    blocker_text='none'
    overall_status='not verified'

    if build_evidence_present "$service"; then
      build_text="yes (\`$(build_evidence_kind "$service")\`)"
    fi

    if image_verified "$service"; then
      image_text='yes'
    fi

    blocker_line="$(grep "^${service}|" "$blockers_file" | head -n 1 || true)"
    if [ -n "$blocker_line" ]; then
      blocker_category="$(printf '%s' "$blocker_line" | cut -d'|' -f2)"
      blocker_suite="$(printf '%s' "$blocker_line" | cut -d'|' -f3)"
      blocker_text="${blocker_category}: ${blocker_suite}"
      if [ "$build_text" != 'no' ] && [ "$image_text" = 'yes' ]; then
        overall_status='package+image verified, full test path blocked'
      elif [ "$build_text" != 'no' ]; then
        overall_status='build artifact verified, full test path blocked'
      else
        overall_status='blocked'
      fi
    elif is_full_build_verified "$service"; then
      if [ "$image_text" = 'yes' ]; then
        overall_status='full build verified + image verified'
      else
        overall_status='full build verified'
      fi
    elif [ "$build_text" != 'no' ] && [ "$image_text" = 'yes' ]; then
      overall_status='package+image verified'
    elif [ "$build_text" != 'no' ]; then
      overall_status='build artifact verified'
    fi

    printf '| %s | %s | %s | %s | %s | %s |\n' "$service" "$workload_type" "$build_text" "$image_text" "$blocker_text" "$overall_status"
  done
} > "$output_file"

printf 'Generated service verification matrix: %s\n' "$output_file"

#!/usr/bin/env sh
set -eu

. scripts/catalog.sh
. scripts/source-root.sh

output_file="${1:-}"
services_file="$(resolve_services_file)"
source_root="$(resolve_source_root)"
override_file="scripts/workspace-blocker-overrides.txt"
emitted_services=""

emit_line() {
  line="$1"
  service_name="${line%%|*}"
  case "|${emitted_services}|" in
    *"|${service_name}|"*) return ;;
  esac
  emitted_services="${emitted_services}|${service_name}"
  if [ -n "$output_file" ]; then
    printf '%s\n' "$line" >> "$output_file"
  else
    printf '%s\n' "$line"
  fi
}

if [ -n "$output_file" ]; then
  mkdir -p "$(dirname "$output_file")"
  : > "$output_file"
fi

if [ ! -f "$services_file" ]; then
  exit 0
fi

iter_catalog_services "$services_file" | while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
  report_dir="${source_root}/${service}/target/failsafe-reports"
  summary_file="${report_dir}/failsafe-summary.xml"

  [ -f "$summary_file" ] || continue

  errors="$(sed -n 's:.*<errors>\([0-9][0-9]*\)</errors>.*:\1:p' "$summary_file" | head -n 1)"
  failures="$(sed -n 's:.*<failures>\([0-9][0-9]*\)</failures>.*:\1:p' "$summary_file" | head -n 1)"
  errors="${errors:-0}"
  failures="${failures:-0}"

  if [ $((errors + failures)) -le 0 ]; then
    continue
  fi

  content="$(cat "$report_dir"/*.txt 2>/dev/null || true)"
  first_report="$(find "$report_dir" -maxdepth 1 -type f -name '*.txt' | sort | head -n 1)"
  failing_report="$(grep -l '<<< FAILURE!\|<<< ERROR!' "$report_dir"/*.txt 2>/dev/null | sort | head -n 1 || true)"
  selected_report="${failing_report:-$first_report}"
  [ -n "${selected_report:-}" ] || continue

  suite_name="$(basename "$selected_report" .txt)"
  category="unknown"
  message="${suite_name} failed during the upstream-style integration phase."

  case "$content" in
    *quay.io/keycloak/keycloak:26.0*|*/health/started*)
      category="keycloak"
      message="${suite_name} failed because Keycloak Testcontainers did not become healthy on /health/started."
      ;;
    *docker.elastic.co/elasticsearch/elasticsearch*|*ProductCdcConsumerTest*|*Elasticsearch*)
      category="elasticsearch"
      message="${suite_name} failed because the Elasticsearch Testcontainers dependency did not become ready."
      ;;
    *"Container startup failed for image "*)
      category="testcontainers"
      image="$(printf '%s' "$content" | sed -n 's:.*Container startup failed for image \([^[:space:]]*\).*:\1:p' | head -n 1)"
      message="${suite_name} failed because Testcontainers could not start image ${image:-unknown}."
      ;;
    *"Failed to load ApplicationContext"*)
      category="spring-context"
      message="${suite_name} failed because the Spring test ApplicationContext could not be created."
      ;;
  esac

  emit_line "${service}|${category}|${suite_name}|${message}"
done

if [ -f "$override_file" ]; then
  while IFS= read -r override_line || [ -n "${override_line:-}" ]; do
    [ -n "${override_line:-}" ] || continue
    case "$override_line" in
      \#*) continue ;;
    esac
    emit_line "$override_line"
  done < "$override_file"
fi

#!/usr/bin/env sh
set -eu

output_file="${1:-work/final-report-notes.generated.md}"
status_report_file="${2:-work/status-report.generated.md}"
service_verification_file="${3:-work/service-verification.generated.md}"
host_capabilities_file="${4:-work/host-capabilities.generated.md}"
baseline_services_file="${5:-jenkins/services.release-baseline.env}"

mkdir -p "$(dirname "$output_file")"

compile_blocked_services=""
keycloak_blocked_services=""
elasticsearch_blocked_services=""
other_blocked_services=""
blockers_file="$(mktemp "${TMPDIR:-/tmp}/yas-final-report-blockers.XXXXXX")"
trap 'rm -f "$blockers_file"' EXIT INT TERM

sh scripts/summarize-failsafe-blockers.sh "$blockers_file" >/dev/null
while IFS='|' read -r service category suite message || [ -n "${service}${category}${suite}${message}" ]; do
  [ -n "${service:-}" ] || continue
  case "$category" in
    compile)
      compile_blocked_services="${compile_blocked_services}${compile_blocked_services:+
}  - \`${service}\`"
      ;;
    keycloak)
      keycloak_blocked_services="${keycloak_blocked_services}${keycloak_blocked_services:+
}  - \`${service}\`"
      ;;
    elasticsearch)
      elasticsearch_blocked_services="${elasticsearch_blocked_services}${elasticsearch_blocked_services:+
}  - \`${service}\`"
      ;;
    *)
      other_blocked_services="${other_blocked_services}- Other blocker: ${service}: ${message}
"
      ;;
  esac
done < "$blockers_file"

{
  printf '# Final Report Notes\n\n'
  printf 'Generated at: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S')"
  printf '%s\n\n' 'Use this file as a prefilled drafting aid alongside [docs/final-report-template.md](../docs/final-report-template.md).'
  printf '## Recommended First Release Subset\n'
  while IFS='|' read -r service path dockerfile port expose node_port workload_type || [ -n "${service}${path}${dockerfile}${port}${expose}${node_port}${workload_type}" ]; do
    case "${service:-}" in
      ''|\#*)
        continue
        ;;
    esac
    printf -- '- `%s`\n' "$service"
  done < "$baseline_services_file"
  printf '\n'
  printf '## What Is Already Verified Locally\n'
  printf '%s\n' '- Source-verified delivery scaffold exists for Jenkins, Helm, ArgoCD, and service mesh.'
  printf '%s\n' '- Local build evidence exists for the UI services `storefront` and `backoffice`.'
  printf '%s\n' '- Full upstream-style Maven build evidence exists for `storefront-bff`, `backoffice-bff`, `product`, `payment`, `payment-paypal`, `recommendation`, `inventory`, and `order`.'
  printf '%s\n' '- Package or build-artifact evidence exists for `cart`, `customer`, `location`, `media`, `promotion`, `rating`, `tax`, `webhook`, `sampledata`, and `search`.'
  printf '%s\n' '- Helm chart lint and template rendering were verified locally.'
  printf '%s\n' '- Generated evidence files are refreshed together by `powershell -ExecutionPolicy Bypass -File scripts\refresh-evidence.ps1 -SkipCommandChecks`.'
  printf '\n'
  printf '## Known Gaps To State Explicitly\n'
  printf '%s\n' '- No real registry push has been verified yet.'
  printf '%s\n' '- No real Kubernetes deployment has been verified yet.'
  printf '%s\n' '- Jenkins credentials, webhooks, registry wiring, and kubeconfig access have not been exercised end to end.'
  if [ -n "$compile_blocked_services" ]; then
    printf '%s\n' '- Compile-path blockers:'
    printf '%s\n' "$compile_blocked_services"
  fi
  if [ -n "$elasticsearch_blocked_services" ]; then
    printf '%s\n' '- Elasticsearch/Testcontainers blockers:'
    printf '%s\n' "$elasticsearch_blocked_services"
  fi
  if [ -n "$keycloak_blocked_services" ]; then
    printf '%s\n' '- Keycloak/Testcontainers blockers:'
    printf '%s\n' "$keycloak_blocked_services"
  fi
  if [ -n "$other_blocked_services" ]; then
    printf '%s' "$other_blocked_services"
  fi
  printf '\n'
  printf '## Evidence Files To Reuse In The Report\n'
  printf '%s\n' '- `work/status-report.generated.md`'
  printf '%s\n' '- `work/service-verification.generated.md`'
  printf '%s\n' '- `work/host-capabilities.generated.md`'
  printf '%s\n' '- `docs/source-build-runtime-matrix.md`'
  printf '%s\n' '- `docs/image-matrix.md`'
  printf '%s\n' '- `work/image-digests.txt` after a real push run'
  printf '%s\n' '- `work/commit-metadata.json` after `dev` or `staging` promotion runs'
  printf '%s\n' '- `work/runtime-evidence/<namespace>/<release>/` after deploy or smoke-test runs'
  printf '%s\n' '- `work/cleanup-evidence/<namespace>/<release>/` after cleanup runs'
  printf '%s\n' '- `work/manifest-update-metadata.json` after GitOps manifest-update runs'
  printf '\n'
  printf '## Suggested Wording For The Conclusion\n'
  printf '%s\n' '- Verified locally only: scaffold structure, source alignment, catalog generation, local builds, local image builds where available, and Helm rendering.'
  printf '%s\n' '- Current host capability evidence: `work/host-capabilities.generated.md` shows which tools and runtime dependencies were actually reachable while the local evidence bundle was generated.'
  printf '%s\n' '- Verified end to end on real infrastructure: leave empty until registry push, Jenkins flow, and cluster deploy evidence exist.'
  printf '%s\n' '- Known accepted gaps: any service intentionally excluded from the first release subset, plus services still blocked by workspace-specific Testcontainers issues.'
} > "$output_file"

printf 'Generated final report notes: %s\n' "$output_file"

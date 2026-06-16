#!/usr/bin/env sh
set -eu

troubleshooting_file="${1:-docs/troubleshooting.md}"
troubleshooting_text="$(cat "$troubleshooting_file")"

while IFS='|' read -r service category suite message || [ -n "${service}${category}${suite}${message}" ]; do
  [ -n "${service:-}" ] || continue
  printf '%s' "$troubleshooting_text" | grep -F -q "\`$service\`" || {
    printf 'docs/troubleshooting.md is missing blocker service `%s`.\n' "$service" >&2
    exit 1
  }
done <<EOF
$(powershell -ExecutionPolicy Bypass -File scripts/summarize-failsafe-blockers.ps1)
EOF

for required_topic in \
  'Docker push authentication failure' \
  'Helm upgrade fails' \
  'NodePort is open but app is unreachable' \
  'Keycloak' \
  'Elasticsearch' \
  'work/service-verification.generated.md' \
  'work/host-capabilities.generated.md' \
  'scripts\refresh-evidence.ps1 -SkipCommandChecks'
do
  printf '%s' "$troubleshooting_text" | grep -F -q "$required_topic" || {
    printf 'docs/troubleshooting.md is missing required troubleshooting topic %s.\n' "$required_topic" >&2
    exit 1
  }
done

printf 'docs/troubleshooting.md is aligned with the current workspace blocker set and runtime troubleshooting topics.\n'

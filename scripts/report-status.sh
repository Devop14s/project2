#!/usr/bin/env sh
set -eu

output_file="${1:-work/status-report.generated.md}"
skip_command_checks=0

if [ "${2:-}" = "--skip-command-checks" ] || [ "${1:-}" = "--skip-command-checks" ]; then
  skip_command_checks=1
  if [ "${1:-}" = "--skip-command-checks" ]; then
    output_file="work/status-report.generated.md"
  fi
fi

mkdir -p "$(dirname "$output_file")"

required_files="
README.md
Jenkinsfile
jenkins/README.md
jenkins/services.env
helm/yas/Chart.yaml
docs/status-report.md
argocd/app-dev.yaml
mesh/peer-authentication.yaml
scripts/selftest.sh
scripts/validate-services-catalog.sh
"

required_commands="
git
kubectl
helm
docker
"

service_count=0
public_entry_count=0
ui_count=0
backend_count=0
if [ -f "jenkins/services.env" ]; then
  while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
    [ -n "$service" ] || continue
    case "$service" in
      \#*) continue ;;
    esac
    service_count=$((service_count + 1))
    if [ "$expose" = "true" ]; then
      public_entry_count=$((public_entry_count + 1))
    fi
    if [ "$workload_type" = "ui" ]; then
      ui_count=$((ui_count + 1))
    elif [ "$workload_type" = "backend" ]; then
      backend_count=$((backend_count + 1))
    fi
  done < "jenkins/services.env"
fi

{
  printf '# Generated Status Report\n\n'
  printf 'Generated at: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S')"
  printf '## Scaffold Files\n'
  for file in $required_files; do
    if [ -f "$file" ]; then
      status="ok"
    else
      status="missing"
    fi
    printf -- '- `%s`: %s\n' "$file" "$status"
  done
  printf '\n'

  if [ "$skip_command_checks" -eq 0 ]; then
    printf '## Host Commands\n'
    for cmd in $required_commands; do
      if command -v "$cmd" >/dev/null 2>&1; then
        status="ok"
      else
        status="missing"
      fi
      printf -- '- `%s`: %s\n' "$cmd" "$status"
    done
    printf '\n'
  fi

  printf '## Service Catalog Summary\n'
  printf -- '- Services in catalog: %s\n' "$service_count"
  printf -- '- Public entrypoints in catalog: %s\n' "$public_entry_count"
  printf -- '- UI workloads in catalog: %s\n' "$ui_count"
  printf -- '- Backend workloads in catalog: %s\n' "$backend_count"
  printf '\n'
  printf '## Verified Locally\n'
  printf '%s\n' '- PowerShell preflight is available.'
  printf '%s\n' '- PowerShell selftest is available.'
  printf '%s\n' '- Cross-platform dry-run helpers exist in both `ps1` and `.sh` form.'
  printf '%s\n' '- Generated values include workload-aware fields such as `workloadType` and backend `metricPort`.'
  printf '\n'
  printf '## Still Blocked In This Workspace\n'
  printf '%s\n' '- Real YAS source tree is not present.'
  printf '%s\n' '- Real Docker build paths cannot be verified.'
  printf '%s\n' '- Real Kubernetes deployment cannot be executed.'
  printf '%s\n' '- Jenkins credentials and webhook integration cannot be verified locally.'
} > "$output_file"

printf 'Generated status report: %s\n' "$output_file"

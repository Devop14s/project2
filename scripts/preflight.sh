#!/usr/bin/env sh
set -eu

skip_command_checks=0
if [ "${1:-}" = "--skip-command-checks" ]; then
  skip_command_checks=1
fi

required_files="
README.md
Jenkinsfile
jenkins/README.md
jenkins/services.env
jenkins/services.release-baseline.env
jenkins/scripts/capture-runtime-evidence.sh
jenkins/scripts/verify-image-tags.sh
jenkins/scripts/write-commit-metadata.sh
helm/yas/Chart.yaml
helm/yas/values.yaml
docs/status-report.md
argocd/app-dev.yaml
mesh/peer-authentication.yaml
scripts/preflight.ps1
scripts/preflight.sh
scripts/developer-build-dry-run.ps1
scripts/developer-build-dry-run.sh
scripts/catalog.ps1
scripts/catalog.sh
scripts/source-root.ps1
scripts/source-root.sh
scripts/selftest.ps1
scripts/selftest.sh
scripts/validate-services-catalog.ps1
scripts/validate-services-catalog.sh
scripts/validate-chart-values.ps1
scripts/validate-chart-values.sh
scripts/validate-gitops-values.ps1
scripts/validate-gitops-values.sh
scripts/validate-source-alignment.ps1
scripts/validate-source-alignment.sh
scripts/report-status.ps1
scripts/report-status.sh
scripts/resolve-branch-tags.ps1
scripts/resolve-branch-tags.sh
scripts/generate-values.ps1
scripts/generate-values.sh
scripts/generate-gitops-values.ps1
scripts/generate-gitops-values.sh
scripts/generate-chart-values.ps1
scripts/generate-chart-values.sh
scripts/update-manifest-values.ps1
scripts/update-manifest-values.sh
"

required_commands="
git
kubectl
helm
docker
"

missing=0
docker_command_available=0
docker_daemon_reachable=0

if command -v docker >/dev/null 2>&1; then
  docker_command_available=1
  if docker version >/dev/null 2>&1; then
    docker_daemon_reachable=1
  fi
fi

printf '%-8s %-40s %-8s\n' "type" "name" "status"

for file in $required_files; do
  if [ -f "$file" ]; then
    status="ok"
  else
    status="missing"
    missing=1
  fi
  printf '%-8s %-40s %-8s\n' "file" "$file" "$status"
done

if [ "$skip_command_checks" -eq 0 ]; then
  for cmd in $required_commands; do
    if [ "$cmd" = "docker" ]; then
      if [ "$docker_command_available" -eq 0 ]; then
        status="missing"
        missing=1
      elif [ "$docker_daemon_reachable" -eq 1 ]; then
        status="ok"
      else
        status="present but daemon inaccessible"
        missing=1
      fi
    else
      if command -v "$cmd" >/dev/null 2>&1; then
        status="ok"
      else
        status="missing"
        missing=1
      fi
    fi
    printf '%-8s %-40s %-8s\n' "command" "$cmd" "$status"
  done
fi

if [ "$missing" -ne 0 ]; then
  printf '\nMissing items detected.\n' >&2
  exit 1
fi

printf '\nAll scaffold preflight checks passed.\n'

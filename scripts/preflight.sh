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
jenkins/pipelines/ci.groovy
jenkins/pipelines/developer_build.groovy
jenkins/pipelines/developer_cleanup.groovy
jenkins/pipelines/dev_cd.groovy
jenkins/pipelines/dev_gitops.groovy
jenkins/pipelines/staging_release.groovy
jenkins/pipelines/staging_gitops.groovy
jenkins/scripts/build-images.sh
jenkins/scripts/capture-runtime-evidence.sh
jenkins/scripts/cleanup-release.sh
jenkins/scripts/common.sh
jenkins/scripts/deploy-helm.sh
jenkins/scripts/docker-login.sh
jenkins/scripts/generate-values.sh
jenkins/scripts/push-images.sh
jenkins/scripts/resolve-branch-tags.sh
jenkins/scripts/smoke-test.sh
jenkins/scripts/update-manifest-repo.sh
jenkins/scripts/verify-image-tags.sh
jenkins/scripts/write-commit-metadata.sh
helm/yas/Chart.yaml
helm/yas/values-dev.yaml
helm/yas/values-staging.yaml
helm/yas/values-developer-template.yaml
helm/yas/values.yaml
docs/status-report.md
argocd/app-dev.yaml
argocd/app-staging.yaml
argocd/values/dev-values.yaml
argocd/values/staging-values.yaml
mesh/authorization-policy.yaml
mesh/destination-rule.yaml
mesh/peer-authentication.yaml
mesh/virtual-service-retry.yaml
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
scripts/validate-argocd-readme.ps1
scripts/validate-argocd-readme.sh
scripts/validate-argocd-apps.ps1
scripts/validate-argocd-apps.sh
scripts/validate-handover-checklist.ps1
scripts/validate-handover-checklist.sh
scripts/validate-services-catalog.ps1
scripts/validate-services-catalog.sh
scripts/validate-chart-values.ps1
scripts/validate-chart-values.sh
scripts/validate-jenkins-readme.ps1
scripts/validate-jenkins-readme.sh
scripts/validate-image-matrix.ps1
scripts/validate-image-matrix.sh
scripts/validate-readme.ps1
scripts/validate-readme.sh
scripts/validate-service-inventory.ps1
scripts/validate-service-inventory.sh
scripts/validate-troubleshooting.ps1
scripts/validate-troubleshooting.sh
scripts/validate-remaining-work-plan.ps1
scripts/validate-remaining-work-plan.sh
scripts/validate-gitops-values.ps1
scripts/validate-gitops-values.sh
scripts/validate-source-alignment.ps1
scripts/validate-source-alignment.sh
scripts/validate-source-build-runtime-matrix.ps1
scripts/validate-source-build-runtime-matrix.sh
scripts/validate-status-report.ps1
scripts/validate-status-report.sh
scripts/summarize-failsafe-blockers.ps1
scripts/summarize-failsafe-blockers.sh
scripts/generate-service-verification-matrix.ps1
scripts/generate-service-verification-matrix.sh
scripts/workspace-blocker-overrides.txt
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

while IFS='|' read -r validator_name validator_command; do
  [ -n "${validator_name:-}" ] || continue

  if sh -c "$validator_command" >/dev/null 2>&1; then
    status="ok"
  else
    status="failed"
    missing=1
  fi

  printf '%-8s %-40s %-8s\n' "validator" "$validator_name" "$status"
done <<'EOF'
validate-services-catalog/full|sh scripts/validate-services-catalog.sh
validate-services-catalog/release-baseline|sh scripts/validate-services-catalog.sh jenkins/services.release-baseline.env jenkins/services.env
validate-argocd-readme|sh scripts/validate-argocd-readme.sh
validate-argocd-apps|sh scripts/validate-argocd-apps.sh
validate-handover-checklist|sh scripts/validate-handover-checklist.sh
validate-chart-values|sh scripts/validate-chart-values.sh
validate-jenkins-readme|sh scripts/validate-jenkins-readme.sh
validate-image-matrix|sh scripts/validate-image-matrix.sh
validate-readme|sh scripts/validate-readme.sh
validate-service-inventory|sh scripts/validate-service-inventory.sh
validate-troubleshooting|sh scripts/validate-troubleshooting.sh
validate-remaining-work-plan|sh scripts/validate-remaining-work-plan.sh
validate-gitops-values|sh scripts/validate-gitops-values.sh
validate-source-alignment|sh scripts/validate-source-alignment.sh
validate-source-build-runtime-matrix|sh scripts/validate-source-build-runtime-matrix.sh
validate-status-report|sh scripts/validate-status-report.sh
EOF

if [ "$missing" -ne 0 ]; then
  printf '\nMissing items detected.\n' >&2
  exit 1
fi

printf '\nAll scaffold preflight checks passed.\n'

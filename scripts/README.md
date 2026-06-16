# Cross-Platform Local Scripts

This directory contains local helper scripts in both PowerShell and POSIX shell form where practical.

The current helpers understand the YAS service catalog format, including `workloadType` values such as `ui` and `backend`.

The generated developer values also keep separate ingress hosts for the public `storefront` and `backoffice` UIs.

The default full catalog remains in `jenkins/services.env`, while the frozen first-release subset lives in `jenkins/services.release-baseline.env`.

You can switch the default catalog for most generators and validators by exporting `SERVICE_CATALOG=release-baseline` instead of passing `SERVICES_FILE` manually.

Source-dependent helpers such as branch-tag resolution and Docker builds now also understand `SOURCE_ROOT` and `SOURCE_GIT_ROOT`. If `yas-source/` exists locally, it becomes the default source tree and Git root automatically.
Branch-tag resolution now also emits `branch-tag-metadata.json`, which records both the requested branch override and the resolved tag per service.

On Windows, `preflight.ps1`, `selftest.ps1`, and `report-status.ps1` can also pick up a portable Helm binary under `work/tools/helm-v*/windows-amd64/helm.exe`, so Helm chart validation does not depend on a global install.

`preflight` and `report-status` now distinguish between the Docker CLI being installed and the Docker daemon actually being reachable. `preflight` also runs the catalog, ArgoCD, chart, GitOps, and source-alignment validators so it catches semantic drift instead of only checking file presence. If you only want to skip host-tool probing, use `-SkipCommandChecks` or `--skip-command-checks`; the repo validators still run.

## Available pairs

- `preflight.ps1`
- `preflight.sh`
- `developer-build-dry-run.ps1`
- `developer-build-dry-run.sh`
- `selftest.ps1`
- `selftest.sh`
- `validate-argocd-readme.ps1`
- `validate-argocd-readme.sh`
- `validate-argocd-apps.ps1`
- `validate-argocd-apps.sh`
- `validate-handover-checklist.ps1`
- `validate-handover-checklist.sh`
- `validate-services-catalog.ps1`
- `validate-services-catalog.sh`
- `validate-chart-values.ps1`
- `validate-chart-values.sh`
- `validate-final-report-template.ps1`
- `validate-final-report-template.sh`
- `validate-jenkins-readme.ps1`
- `validate-jenkins-readme.sh`
- `validate-image-matrix.ps1`
- `validate-image-matrix.sh`
- `validate-mesh-readme.ps1`
- `validate-mesh-readme.sh`
- `validate-operations-docs.ps1`
- `validate-operations-docs.sh`
- `validate-readme.ps1`
- `validate-readme.sh`
- `validate-service-inventory.ps1`
- `validate-service-inventory.sh`
- `validate-troubleshooting.ps1`
- `validate-troubleshooting.sh`
- `validate-remaining-work-plan.ps1`
- `validate-remaining-work-plan.sh`
- `validate-gitops-values.ps1`
- `validate-gitops-values.sh`
- `validate-generated-reports.ps1`
- `validate-generated-reports.sh`
- `validate-source-alignment.ps1`
- `validate-source-alignment.sh`
- `validate-source-build-runtime-matrix.ps1`
- `validate-source-build-runtime-matrix.sh`
- `validate-status-report.ps1`
- `validate-status-report.sh`
- `summarize-failsafe-blockers.ps1`
- `summarize-failsafe-blockers.sh`
- `generate-service-verification-matrix.ps1`
- `generate-service-verification-matrix.sh`
- `workspace-blocker-overrides.txt`
- `report-status.ps1`
- `report-status.sh`
- `resolve-branch-tags.ps1`
- `resolve-branch-tags.sh`
- `generate-values.ps1`
- `generate-values.sh`
- `generate-gitops-values.ps1`
- `generate-gitops-values.sh`
- `generate-chart-values.ps1`
- `generate-chart-values.sh`
- `update-manifest-values.ps1`
- `update-manifest-values.sh`

## Recommended usage

### Windows PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File scripts\preflight.ps1
powershell -ExecutionPolicy Bypass -File scripts\preflight.ps1 -SkipCommandChecks
powershell -ExecutionPolicy Bypass -File scripts\developer-build-dry-run.ps1 -DockerhubNamespace your-dockerhub-namespace
powershell -ExecutionPolicy Bypass -File scripts\developer-build-dry-run.ps1 -DockerhubNamespace your-dockerhub-namespace -ServiceCatalog release-baseline
powershell -ExecutionPolicy Bypass -File scripts\selftest.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-argocd-readme.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-argocd-apps.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-handover-checklist.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-services-catalog.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-services-catalog.ps1 -ServicesFile jenkins\services.release-baseline.env -ReferenceServicesFile jenkins\services.env
powershell -ExecutionPolicy Bypass -File scripts\validate-chart-values.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-final-report-template.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-jenkins-readme.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-image-matrix.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-mesh-readme.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-operations-docs.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-readme.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-service-inventory.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-troubleshooting.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-remaining-work-plan.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-gitops-values.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-generated-reports.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-source-alignment.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-source-build-runtime-matrix.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-status-report.ps1
powershell -ExecutionPolicy Bypass -File scripts\summarize-failsafe-blockers.ps1
powershell -ExecutionPolicy Bypass -File scripts\generate-service-verification-matrix.ps1
powershell -ExecutionPolicy Bypass -File scripts\report-status.ps1 -SkipCommandChecks
powershell -ExecutionPolicy Bypass -File scripts\resolve-branch-tags.ps1
powershell -ExecutionPolicy Bypass -File scripts\generate-values.ps1 -DockerhubNamespace your-dockerhub-namespace
$env:SERVICE_CATALOG='release-baseline'; powershell -ExecutionPolicy Bypass -File scripts\generate-values.ps1 -DockerhubNamespace your-dockerhub-namespace
powershell -ExecutionPolicy Bypass -File scripts\generate-gitops-values.ps1 -EnvironmentName dev -OutputFile argocd\values\dev-values.yaml
powershell -ExecutionPolicy Bypass -File scripts\generate-chart-values.ps1 -OutputFile helm\yas\values.yaml
powershell -ExecutionPolicy Bypass -File scripts\update-manifest-values.ps1 -ValuesFile argocd\values\dev-values.yaml -Tag main
```

### Linux or macOS

```bash
sh scripts/preflight.sh
sh scripts/preflight.sh --skip-command-checks
sh scripts/developer-build-dry-run.sh your-dockerhub-namespace
sh scripts/developer-build-dry-run.sh your-dockerhub-namespace work/dry-run release-baseline
sh scripts/selftest.sh
sh scripts/validate-argocd-readme.sh
sh scripts/validate-argocd-apps.sh
sh scripts/validate-handover-checklist.sh
sh scripts/validate-services-catalog.sh
sh scripts/validate-services-catalog.sh jenkins/services.release-baseline.env jenkins/services.env
sh scripts/validate-chart-values.sh
sh scripts/validate-final-report-template.sh
sh scripts/validate-jenkins-readme.sh
sh scripts/validate-image-matrix.sh
sh scripts/validate-mesh-readme.sh
sh scripts/validate-operations-docs.sh
sh scripts/validate-readme.sh
sh scripts/validate-service-inventory.sh
sh scripts/validate-troubleshooting.sh
sh scripts/validate-remaining-work-plan.sh
sh scripts/validate-gitops-values.sh
sh scripts/validate-generated-reports.sh
sh scripts/validate-source-alignment.sh
sh scripts/validate-source-build-runtime-matrix.sh
sh scripts/validate-status-report.sh
sh scripts/summarize-failsafe-blockers.sh
sh scripts/generate-service-verification-matrix.sh
sh scripts/report-status.sh --skip-command-checks
sh scripts/resolve-branch-tags.sh
DOCKERHUB_NAMESPACE=your-dockerhub-namespace sh scripts/generate-values.sh
SERVICE_CATALOG=release-baseline DOCKERHUB_NAMESPACE=your-dockerhub-namespace sh scripts/generate-values.sh
ENVIRONMENT=dev OUTPUT_FILE=argocd/values/dev-values.yaml sh scripts/generate-gitops-values.sh
OUTPUT_FILE=helm/yas/values.yaml sh scripts/generate-chart-values.sh
sh scripts/update-manifest-values.sh argocd/values/dev-values.yaml main
```

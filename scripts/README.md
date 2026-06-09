# Cross-Platform Local Scripts

This directory contains local helper scripts in both PowerShell and POSIX shell form where practical.

The current helpers understand the YAS service catalog format, including `workloadType` values such as `ui` and `backend`.

The generated developer values also keep separate ingress hosts for the public `storefront` and `backoffice` UIs.

On Windows, `preflight.ps1`, `selftest.ps1`, and `report-status.ps1` can also pick up a portable Helm binary under `work/tools/helm-v*/windows-amd64/helm.exe`, so Helm chart validation does not depend on a global install.

## Available pairs

- `preflight.ps1`
- `preflight.sh`
- `developer-build-dry-run.ps1`
- `developer-build-dry-run.sh`
- `selftest.ps1`
- `selftest.sh`
- `validate-services-catalog.ps1`
- `validate-services-catalog.sh`
- `validate-chart-values.ps1`
- `validate-chart-values.sh`
- `validate-source-alignment.ps1`
- `validate-source-alignment.sh`
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
powershell -ExecutionPolicy Bypass -File scripts\selftest.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-services-catalog.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-chart-values.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-source-alignment.ps1
powershell -ExecutionPolicy Bypass -File scripts\report-status.ps1 -SkipCommandChecks
powershell -ExecutionPolicy Bypass -File scripts\resolve-branch-tags.ps1
powershell -ExecutionPolicy Bypass -File scripts\generate-values.ps1 -DockerhubNamespace your-dockerhub-namespace
powershell -ExecutionPolicy Bypass -File scripts\generate-gitops-values.ps1 -EnvironmentName dev -OutputFile argocd\values\dev-values.yaml
powershell -ExecutionPolicy Bypass -File scripts\generate-chart-values.ps1 -OutputFile helm\yas\values.yaml
powershell -ExecutionPolicy Bypass -File scripts\update-manifest-values.ps1 -ValuesFile argocd\values\dev-values.yaml -Tag main
```

### Linux or macOS

```bash
sh scripts/preflight.sh
sh scripts/preflight.sh --skip-command-checks
sh scripts/developer-build-dry-run.sh your-dockerhub-namespace
sh scripts/selftest.sh
sh scripts/validate-services-catalog.sh
sh scripts/validate-chart-values.sh
sh scripts/validate-source-alignment.sh
sh scripts/report-status.sh --skip-command-checks
sh scripts/resolve-branch-tags.sh
DOCKERHUB_NAMESPACE=your-dockerhub-namespace sh scripts/generate-values.sh
ENVIRONMENT=dev OUTPUT_FILE=argocd/values/dev-values.yaml sh scripts/generate-gitops-values.sh
OUTPUT_FILE=helm/yas/values.yaml sh scripts/generate-chart-values.sh
sh scripts/update-manifest-values.sh argocd/values/dev-values.yaml main
```

# Local Dry Run

## Goal

Simulate the `developer_build` branch override flow locally without Jenkins, Kubernetes, or Helm.

## Outputs

- `branch-tags.env`
- `generated-values.yaml`

## Windows PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File scripts\developer-build-dry-run.ps1 -DockerhubNamespace your-dockerhub-namespace
```

Example with a service override:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\developer-build-dry-run.ps1 `
  -DockerhubNamespace your-dockerhub-namespace `
  -TaxBranch dev_tax_service
```

## Linux or macOS

```bash
sh scripts/developer-build-dry-run.sh your-dockerhub-namespace
```

Override branches by exporting environment variables first:

```bash
TAX_BRANCH=dev_tax_service sh scripts/developer-build-dry-run.sh your-dockerhub-namespace
```

## What this validates

- service-to-branch mapping
- branch-to-tag resolution
- generated values structure
- NodePort exposure for public entrypoints
- workload-aware fields such as `workloadType` and backend `metricPort`

## Extra scaffold validation

Use the local selftest when you want a quick end-to-end check of the helper scripts themselves:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\selftest.ps1
```

```bash
sh scripts/selftest.sh
```

Validate the service catalog before wiring the real repo paths:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\validate-services-catalog.ps1
```

```bash
sh scripts/validate-services-catalog.sh
```

Generate a current-state markdown report for the scaffold:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\report-status.ps1 -SkipCommandChecks
```

```bash
sh scripts/report-status.sh --skip-command-checks
```

If your machine does not yet have all runtime tools such as `helm`, you can still validate scaffold completeness only:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\preflight.ps1 -SkipCommandChecks
```

```bash
sh scripts/preflight.sh --skip-command-checks
```

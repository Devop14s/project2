# Local Dry Run

## Goal

Simulate the `developer_build` branch override flow locally without Jenkins, Kubernetes, or Helm.

If `yas-source-upstream/` exists beside this delivery repo, branch-tag resolution automatically uses that source checkout. If it is absent but `yas-source/` exists, the scripts fall back to that clone. Override with `SOURCE_GIT_ROOT` only when needed.

For Jenkins usage, the top-level `Jenkinsfile` and the direct-load pipeline entrypoints both default to cloning `https://github.com/nashtech-garage/yas.git` into `yas-source-upstream/` when the source checkout is missing from the agent workspace. Override `SOURCE_REPO_URL` or `SOURCE_REPO_REF` only when the agent should fetch from a different remote or ref.

## Outputs

- `branch-tags.env`
- `branch-tag-metadata.json`
- `generated-values.yaml`

## Windows PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File scripts\developer-build-dry-run.ps1 -DockerhubNamespace your-dockerhub-namespace
```

Use the frozen subset instead of the full catalog:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\developer-build-dry-run.ps1 -DockerhubNamespace your-dockerhub-namespace -ServiceCatalog release-baseline
```

Example with a service override:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\developer-build-dry-run.ps1 `
  -DockerhubNamespace your-dockerhub-namespace `
  -TaxBranch dev_tax_service
```

The PowerShell dry-run now mirrors the full Jenkins `developer_build` branch-override surface, so you can pass parameters such as `-StorefrontBranch`, `-BackofficeBranch`, `-PaymentBranch`, or any other service-specific override supported by the pipeline.

## Linux or macOS

```bash
sh scripts/developer-build-dry-run.sh your-dockerhub-namespace
```

Use the frozen subset instead of the full catalog:

```bash
sh scripts/developer-build-dry-run.sh your-dockerhub-namespace work/dry-run release-baseline
```

Override branches by exporting environment variables first:

```bash
TAX_BRANCH=dev_tax_service sh scripts/developer-build-dry-run.sh your-dockerhub-namespace
```

## What this validates

- service-to-branch mapping
- branch-to-tag resolution
- persisted branch/tag provenance for each selected service
- generated values structure
- NodePort exposure for public entrypoints
- workload-aware fields such as `workloadType` and backend `metricPort`
- distinct ingress hosts for `storefront` and `backoffice`
- service-catalog selection between `full` and `release-baseline`

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

Generate the current-state markdown evidence set for the scaffold:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\refresh-evidence.ps1 -SkipCommandChecks
```

```bash
sh scripts/refresh-evidence.sh --skip-command-checks
```

This refreshes `work/status-report.generated.md`, `work/service-verification.generated.md`, `work/final-report-notes.generated.md`, and `work/host-capabilities.generated.md` together so the high-level summary, per-service matrix, report-drafting notes, and host/runtime snapshot stay in sync.

If your machine does not yet have all runtime tools such as `helm`, you can still validate scaffold completeness only:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\preflight.ps1 -SkipCommandChecks
```

```bash
sh scripts/preflight.sh --skip-command-checks
```

When command checks are enabled, `preflight` now treats "Docker CLI installed but daemon unreachable" as a failed prerequisite instead of reporting Docker as fully available.

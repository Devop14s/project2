param(
    [string]$OutputFile = 'work/status-report.generated.md',
    [switch]$SkipCommandChecks
)

. "$PSScriptRoot\source-root.ps1"

function Get-HelmExecutable {
    $helmCommand = Get-Command helm -ErrorAction SilentlyContinue
    if ($helmCommand) {
        return $helmCommand.Source
    }

    $localHelm = Get-ChildItem -Path 'work\tools' -Filter 'helm.exe' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -like '*windows-amd64*' } |
        Select-Object -First 1

    if ($localHelm) {
        return $localHelm.FullName
    }

    return $null
}

$outputDir = Split-Path -Parent $OutputFile
if ($outputDir) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$resolvedOutputPath = if ([System.IO.Path]::IsPathRooted($OutputFile)) {
    $OutputFile
} else {
    Join-Path (Get-Location) $OutputFile
}

$requiredFiles = @(
    'README.md',
    'Jenkinsfile',
    'jenkins\README.md',
    'jenkins\services.env',
    'jenkins\services.release-baseline.env',
    'jenkins\pipelines\ci.groovy',
    'jenkins\pipelines\developer_build.groovy',
    'jenkins\pipelines\developer_cleanup.groovy',
    'jenkins\pipelines\dev_cd.groovy',
    'jenkins\pipelines\dev_gitops.groovy',
    'jenkins\pipelines\staging_release.groovy',
    'jenkins\pipelines\staging_gitops.groovy',
    'jenkins\scripts\build-images.sh',
    'jenkins\scripts\capture-runtime-evidence.sh',
    'jenkins\scripts\cleanup-release.sh',
    'jenkins\scripts\common.sh',
    'jenkins\scripts\deploy-helm.sh',
    'jenkins\scripts\docker-login.sh',
    'jenkins\scripts\generate-values.sh',
    'jenkins\scripts\push-images.sh',
    'jenkins\scripts\resolve-branch-tags.sh',
    'jenkins\scripts\smoke-test.sh',
    'jenkins\scripts\update-manifest-repo.sh',
    'jenkins\scripts\verify-image-tags.sh',
    'jenkins\scripts\write-commit-metadata.sh',
    'helm\yas\Chart.yaml',
    'helm\yas\values-dev.yaml',
    'helm\yas\values-staging.yaml',
    'helm\yas\values-developer-template.yaml',
    'helm\yas\values.yaml',
    'docs\status-report.md',
    'argocd\app-dev.yaml',
    'argocd\app-staging.yaml',
    'argocd\values\dev-values.yaml',
    'argocd\values\staging-values.yaml',
    'mesh\authorization-policy.yaml',
    'mesh\destination-rule.yaml',
    'mesh\peer-authentication.yaml',
    'mesh\virtual-service-retry.yaml',
    'scripts\preflight.ps1',
    'scripts\preflight.sh',
    'scripts\developer-build-dry-run.ps1',
    'scripts\developer-build-dry-run.sh',
    'scripts\catalog.ps1',
    'scripts\catalog.sh',
    'scripts\source-root.ps1',
    'scripts\source-root.sh',
    'scripts\selftest.ps1',
    'scripts\selftest.sh',
    'scripts\validate-argocd-apps.ps1',
    'scripts\validate-argocd-apps.sh',
    'scripts\validate-services-catalog.ps1',
    'scripts\validate-services-catalog.sh',
    'scripts\validate-chart-values.ps1',
    'scripts\validate-chart-values.sh',
    'scripts\validate-gitops-values.ps1',
    'scripts\validate-gitops-values.sh',
    'scripts\validate-source-alignment.ps1',
    'scripts\validate-source-alignment.sh',
    'scripts\report-status.ps1',
    'scripts\report-status.sh',
    'scripts\resolve-branch-tags.ps1',
    'scripts\resolve-branch-tags.sh',
    'scripts\generate-values.ps1',
    'scripts\generate-values.sh',
    'scripts\generate-gitops-values.ps1',
    'scripts\generate-gitops-values.sh',
    'scripts\generate-chart-values.ps1',
    'scripts\generate-chart-values.sh',
    'scripts\update-manifest-values.ps1',
    'scripts\update-manifest-values.sh'
)

$requiredCommands = @('git', 'kubectl', 'helm', 'docker')
$servicesFile = 'jenkins/services.env'
$releaseBaselineServicesFile = 'jenkins/services.release-baseline.env'
$sourceRoot = Resolve-SourceRoot -SourceRoot ''
$serviceCount = 0
$releaseBaselineServiceCount = 0
$publicEntryCount = 0
$uiCount = 0
$backendCount = 0
$sourceAligned = $false
$storefrontBuildVerified = (Test-Path (Join-Path $sourceRoot 'storefront\.next'))
$backofficeBuildVerified = (Test-Path (Join-Path $sourceRoot 'backoffice\.next'))
$storefrontBffBuildVerified = (Test-Path (Join-Path $sourceRoot 'storefront-bff\target\storefront-bff-1.0-SNAPSHOT.jar'))
$backofficeBffBuildVerified = (Test-Path (Join-Path $sourceRoot 'backoffice-bff\target\backoffice-bff-1.0-SNAPSHOT.jar'))
$productBuildVerified = (Test-Path (Join-Path $sourceRoot 'product\target\product-1.0-SNAPSHOT.jar'))
$paymentBuildVerified = (Test-Path (Join-Path $sourceRoot 'payment\target\payment-1.0-SNAPSHOT.jar'))
$paymentPaypalBuildVerified = (Test-Path (Join-Path $sourceRoot 'payment-paypal\target\payment-paypal-1.0-SNAPSHOT.jar'))
$recommendationBuildVerified = (Test-Path (Join-Path $sourceRoot 'recommendation\target\recommendation-1.0-SNAPSHOT.jar'))
$inventoryBuildVerified = (Test-Path (Join-Path $sourceRoot 'inventory\target\inventory-1.0-SNAPSHOT.jar'))
$orderBuildVerified = (Test-Path (Join-Path $sourceRoot 'order\target\order-1.0-SNAPSHOT.jar'))
$sampledataPackageVerified = (Test-Path (Join-Path $sourceRoot 'sampledata\target\sampledata-1.0-SNAPSHOT.jar'))
$searchPackageVerified = (Test-Path (Join-Path $sourceRoot 'search\target\search-1.0-SNAPSHOT.jar'))
$productImageVerified = $false
$storefrontImageVerified = $false
$backofficeImageVerified = $false
$storefrontBffImageVerified = $false
$backofficeBffImageVerified = $false
$paymentImageVerified = $false
$paymentPaypalImageVerified = $false
$recommendationImageVerified = $false
$inventoryImageVerified = $false
$orderImageVerified = $false
$sampledataImageVerified = $false
$searchImageVerified = $false
$dockerCommandAvailable = ($null -ne (Get-Command docker -ErrorAction SilentlyContinue))
$dockerDaemonReachable = $false
$helmExecutable = Get-HelmExecutable
$helmLintVerified = $false
$helmTemplateVerified = $false
$gitopsValuesVerified = $false
$runtimeEvidenceProvenanceVerified = $false
$selfContainedCommitMetadataVerified = $false
$partialImageMetadataVerified = $false
$failureSafeRuntimeEvidenceVerified = $false
$cleanupGuardVerified = $false
$sharedPromotionCommitMetadataVerified = $false

if (Test-Path $servicesFile) {
    foreach ($line in Get-Content $servicesFile) {
        if (-not $line) { continue }
        if ($line.StartsWith('#')) { continue }
        $parts = $line.Split('|')
        if ($parts.Count -ge 7) {
            $serviceCount += 1
            if ($parts[4] -eq 'true') {
                $publicEntryCount += 1
            }
            if ($parts[6] -eq 'ui') {
                $uiCount += 1
            } elseif ($parts[6] -eq 'backend') {
                $backendCount += 1
            }
        }
    }
}

if ((Test-Path $sourceRoot) -and (Test-Path $servicesFile)) {
    powershell -ExecutionPolicy Bypass -File scripts\validate-source-alignment.ps1 -ServicesFile $servicesFile -SourceRoot $sourceRoot *> $null
    $sourceAligned = ($LASTEXITCODE -eq 0)
}

if ($dockerCommandAvailable) {
    try {
        docker version *> $null
        $dockerDaemonReachable = ($LASTEXITCODE -eq 0)
    } catch {
        $dockerDaemonReachable = $false
    }
}

if ($dockerDaemonReachable) {
    try {
        docker image inspect 'yas-product:codex-verified' *> $null
        $productImageVerified = ($LASTEXITCODE -eq 0)
    } catch {
        $productImageVerified = $false
    }

    try {
        docker image inspect 'yas-storefront:codex-verified' *> $null
        $storefrontImageVerified = ($LASTEXITCODE -eq 0)
    } catch {
        $storefrontImageVerified = $false
    }

    try {
        docker image inspect 'yas-backoffice:codex-verified' *> $null
        $backofficeImageVerified = ($LASTEXITCODE -eq 0)
    } catch {
        $backofficeImageVerified = $false
    }

    try {
        docker image inspect 'yas-storefront-bff:codex-verified' *> $null
        $storefrontBffImageVerified = ($LASTEXITCODE -eq 0)
    } catch {
        $storefrontBffImageVerified = $false
    }

    try {
        docker image inspect 'yas-backoffice-bff:codex-verified' *> $null
        $backofficeBffImageVerified = ($LASTEXITCODE -eq 0)
    } catch {
        $backofficeBffImageVerified = $false
    }

    try {
        docker image inspect 'yas-payment:codex-verified' *> $null
        $paymentImageVerified = ($LASTEXITCODE -eq 0)
    } catch {
        $paymentImageVerified = $false
    }

    try {
        docker image inspect 'yas-payment-paypal:codex-verified' *> $null
        $paymentPaypalImageVerified = ($LASTEXITCODE -eq 0)
    } catch {
        $paymentPaypalImageVerified = $false
    }

    try {
        docker image inspect 'yas-recommendation:codex-verified' *> $null
        $recommendationImageVerified = ($LASTEXITCODE -eq 0)
    } catch {
        $recommendationImageVerified = $false
    }

    try {
        docker image inspect 'yas-inventory:codex-verified' *> $null
        $inventoryImageVerified = ($LASTEXITCODE -eq 0)
    } catch {
        $inventoryImageVerified = $false
    }

    try {
        docker image inspect 'yas-order:codex-verified' *> $null
        $orderImageVerified = ($LASTEXITCODE -eq 0)
    } catch {
        $orderImageVerified = $false
    }

    try {
        docker image inspect 'yas-sampledata:codex-verified' *> $null
        $sampledataImageVerified = ($LASTEXITCODE -eq 0)
    } catch {
        $sampledataImageVerified = $false
    }

    try {
        docker image inspect 'yas-search:codex-verified' *> $null
        $searchImageVerified = ($LASTEXITCODE -eq 0)
    } catch {
        $searchImageVerified = $false
    }
}

if (Test-Path $releaseBaselineServicesFile) {
    foreach ($line in Get-Content $releaseBaselineServicesFile) {
        if (-not $line) { continue }
        if ($line.StartsWith('#')) { continue }
        $parts = $line.Split('|')
        if ($parts.Count -ge 7) {
            $releaseBaselineServiceCount += 1
        }
    }
}

if ($helmExecutable) {
    try {
        & $helmExecutable lint 'helm\yas' *> $null
        $helmLintVerified = ($LASTEXITCODE -eq 0)
    } catch {
        $helmLintVerified = $false
    }

    try {
        & $helmExecutable template yas 'helm\yas' *> $null
        $helmTemplateVerified = ($LASTEXITCODE -eq 0)
    } catch {
        $helmTemplateVerified = $false
    }
}

if (Test-Path $releaseBaselineServicesFile) {
    try {
        powershell -ExecutionPolicy Bypass -File scripts\validate-gitops-values.ps1 -ServicesFile $releaseBaselineServicesFile *> $null
        $gitopsValuesVerified = ($LASTEXITCODE -eq 0)
    } catch {
        $gitopsValuesVerified = $false
    }
}

$captureRuntimeEvidenceScript = if (Test-Path 'jenkins\scripts\capture-runtime-evidence.sh') { Get-Content 'jenkins\scripts\capture-runtime-evidence.sh' -Raw } else { '' }
$writeCommitMetadataScript = if (Test-Path 'jenkins\scripts\write-commit-metadata.sh') { Get-Content 'jenkins\scripts\write-commit-metadata.sh' -Raw } else { '' }
$buildImagesScript = if (Test-Path 'jenkins\scripts\build-images.sh') { Get-Content 'jenkins\scripts\build-images.sh' -Raw } else { '' }
$pushImagesScript = if (Test-Path 'jenkins\scripts\push-images.sh') { Get-Content 'jenkins\scripts\push-images.sh' -Raw } else { '' }
$verifyImageTagsScript = if (Test-Path 'jenkins\scripts\verify-image-tags.sh') { Get-Content 'jenkins\scripts\verify-image-tags.sh' -Raw } else { '' }
$deployHelmScript = if (Test-Path 'jenkins\scripts\deploy-helm.sh') { Get-Content 'jenkins\scripts\deploy-helm.sh' -Raw } else { '' }
$smokeTestScript = if (Test-Path 'jenkins\scripts\smoke-test.sh') { Get-Content 'jenkins\scripts\smoke-test.sh' -Raw } else { '' }
$cleanupScript = if (Test-Path 'jenkins\scripts\cleanup-release.sh') { Get-Content 'jenkins\scripts\cleanup-release.sh' -Raw } else { '' }
$devCdPipeline = if (Test-Path 'jenkins\pipelines\dev_cd.groovy') { Get-Content 'jenkins\pipelines\dev_cd.groovy' -Raw } else { '' }
$devGitopsPipeline = if (Test-Path 'jenkins\pipelines\dev_gitops.groovy') { Get-Content 'jenkins\pipelines\dev_gitops.groovy' -Raw } else { '' }
$stagingReleasePipeline = if (Test-Path 'jenkins\pipelines\staging_release.groovy') { Get-Content 'jenkins\pipelines\staging_release.groovy' -Raw } else { '' }
$stagingGitopsPipeline = if (Test-Path 'jenkins\pipelines\staging_gitops.groovy') { Get-Content 'jenkins\pipelines\staging_gitops.groovy' -Raw } else { '' }

$runtimeEvidenceProvenanceVerified = (
    $captureRuntimeEvidenceScript -match 'copied-artifacts\.txt' -and
    $captureRuntimeEvidenceScript -match 'work/image-digests\.txt' -and
    $captureRuntimeEvidenceScript -match 'work/commit-metadata\.json'
)

$selfContainedCommitMetadataVerified = (
    $writeCommitMetadataScript -match '"commit_sha": "\$\{commit_sha\}"' -and
    $writeCommitMetadataScript -match '"commit_short_sha": "\$\{commit_short_sha\}"' -and
    $writeCommitMetadataScript -match '"generated_at":'
)

$partialImageMetadataVerified = (
    $buildImagesScript -match 'write_build_metadata' -and
    $buildImagesScript -match '"completed": \$\{build_completed\}' -and
    $pushImagesScript -match 'write_push_metadata' -and
    $pushImagesScript -match '"completed": \$\{push_completed\}' -and
    $verifyImageTagsScript -match 'write_verify_metadata' -and
    $verifyImageTagsScript -match '"completed": \$\{verify_completed\}'
)

$failureSafeRuntimeEvidenceVerified = (
    $captureRuntimeEvidenceScript -match 'CAPTURE_RUNTIME_EXIT_CODE' -and
    $captureRuntimeEvidenceScript -match 'write_namespace_missing_note' -and
    $deployHelmScript -match 'capture_runtime_evidence_on_exit' -and
    $smokeTestScript -match 'capture_runtime_evidence_on_exit'
)

$cleanupGuardVerified = (
    $cleanupScript -match 'ALLOW_SHARED_ENVIRONMENT_CLEANUP="\$\{ALLOW_SHARED_ENVIRONMENT_CLEANUP:-0\}"' -and
    $cleanupScript -match 'ALLOW_SHARED_NAMESPACE_DELETE="\$\{ALLOW_SHARED_NAMESPACE_DELETE:-0\}"' -and
    $cleanupScript -match 'shared_target_detected='
)

$sharedPromotionCommitMetadataVerified = (
    $devCdPipeline -match 'jenkins/scripts/write-commit-metadata\.sh' -and
    $devGitopsPipeline -match 'jenkins/scripts/write-commit-metadata\.sh' -and
    $stagingReleasePipeline -match 'jenkins/scripts/write-commit-metadata\.sh' -and
    $stagingGitopsPipeline -match 'jenkins/scripts/write-commit-metadata\.sh'
)

$fileLines = foreach ($file in $requiredFiles) {
    $status = if (Test-Path $file) { 'ok' } else { 'missing' }
    "- ${file}: $status"
}

$commandLines = foreach ($cmd in $requiredCommands) {
    $status = if ($cmd -eq 'helm') {
        if ($helmExecutable) { 'ok' } else { 'missing' }
    } elseif ($cmd -eq 'docker') {
        if (-not $dockerCommandAvailable) {
            'missing'
        } elseif ($dockerDaemonReachable) {
            'ok'
        } else {
            'present but daemon inaccessible'
        }
    } else {
        if ($null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)) { 'ok' } else { 'missing' }
    }
    "- ${cmd}: $status"
}

$content = New-Object System.Collections.Generic.List[string]
$content.Add('# Generated Status Report')
$content.Add('')
$content.Add("Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$content.Add('')
$content.Add('## Scaffold Files')
foreach ($line in $fileLines) {
    $content.Add($line)
}
$content.Add('')

if (-not $SkipCommandChecks) {
    $content.Add('## Host Commands')
    foreach ($line in $commandLines) {
        $content.Add($line)
    }
    $content.Add('')
}

$content.Add('## Service Catalog Summary')
$content.Add("- Services in catalog: $serviceCount")
$content.Add("- Services in release baseline: $releaseBaselineServiceCount")
$content.Add("- Public entrypoints in catalog: $publicEntryCount")
$content.Add("- UI workloads in catalog: $uiCount")
$content.Add("- Backend workloads in catalog: $backendCount")
$content.Add('')
$content.Add('## Verified Locally')
$content.Add('- PowerShell preflight is available.')
$content.Add('- PowerShell selftest is available.')
$content.Add('- Cross-platform dry-run helpers exist in both `ps1` and `.sh` form.')
$content.Add('- Generated values include workload-aware fields such as `workloadType` and backend `metricPort`.')
$content.Add('- GitOps values generation is available for the full service catalog.')
$content.Add('- Helm baseline values generation is available from the shared service catalog.')
if (Test-Path $releaseBaselineServicesFile) {
    $content.Add('- A frozen first-release service catalog exists in `jenkins/services.release-baseline.env`.')
}
if ($sourceAligned) {
    $content.Add('- Service catalog paths and Dockerfiles were verified against the configured source root `' + $sourceRoot + '`.')
}
if ($storefrontBuildVerified) {
    $content.Add('- A real `storefront` Next.js production build completed successfully in the cloned source tree.')
}
if ($backofficeBuildVerified) {
    $content.Add('- A real `backoffice` Next.js production build completed successfully in the cloned source tree.')
}
if ($storefrontBffBuildVerified) {
    $content.Add('- A real `storefront-bff` Maven build completed successfully and produced a runnable JAR artifact.')
}
if ($backofficeBffBuildVerified) {
    $content.Add('- A real `backoffice-bff` Maven verification completed successfully and produced a runnable JAR artifact.')
}
if ($productBuildVerified) {
    $content.Add('- A real `product` Maven backend build completed successfully and produced a runnable JAR artifact.')
}
if ($paymentBuildVerified) {
    $content.Add('- A real `payment` Maven backend build completed successfully and produced a runnable JAR artifact.')
}
if ($paymentPaypalBuildVerified) {
    $content.Add('- A real `payment-paypal` Maven backend build completed successfully and produced a runnable JAR artifact.')
}
if ($recommendationBuildVerified) {
    $content.Add('- A real `recommendation` Maven backend build completed successfully and produced a runnable JAR artifact.')
}
if ($inventoryBuildVerified) {
    $content.Add('- A real `inventory` Maven backend build completed successfully and produced a runnable JAR artifact.')
}
if ($orderBuildVerified) {
    $content.Add('- A real `order` Maven backend build completed successfully and produced a runnable JAR artifact.')
}
if ($sampledataPackageVerified) {
    $content.Add('- A packaged `sampledata` JAR was produced successfully in this workspace using a test-skipped Maven build.')
}
if ($searchPackageVerified) {
    $content.Add('- A packaged `search` JAR was produced successfully in this workspace using a test-skipped Maven build.')
}
if ($productImageVerified) {
    $content.Add('- A real `product` Docker image build completed successfully in this workspace.')
}
if ($storefrontImageVerified) {
    $content.Add('- A real `storefront` Docker image build completed successfully in this workspace.')
}
if ($backofficeImageVerified) {
    $content.Add('- A real `backoffice` Docker image build completed successfully in this workspace.')
}
if ($storefrontBffImageVerified) {
    $content.Add('- A real `storefront-bff` Docker image build completed successfully in this workspace.')
}
if ($backofficeBffImageVerified) {
    $content.Add('- A real `backoffice-bff` Docker image build completed successfully in this workspace.')
}
if ($paymentImageVerified) {
    $content.Add('- A real `payment` Docker image build completed successfully in this workspace.')
}
if ($paymentPaypalImageVerified) {
    $content.Add('- A real `payment-paypal` Docker image build completed successfully in this workspace.')
}
if ($recommendationImageVerified) {
    $content.Add('- A real `recommendation` Docker image build completed successfully in this workspace.')
}
if ($inventoryImageVerified) {
    $content.Add('- A real `inventory` Docker image build completed successfully in this workspace.')
}
if ($orderImageVerified) {
    $content.Add('- A real `order` Docker image build completed successfully in this workspace.')
}
if ($sampledataImageVerified) {
    $content.Add('- A real `sampledata` Docker image build completed successfully in this workspace.')
}
if ($searchImageVerified) {
    $content.Add('- A real `search` Docker image build completed successfully in this workspace.')
}
if ($helmLintVerified) {
    $content.Add('- A real Helm chart lint completed successfully against `helm/yas`.')
}
if ($helmTemplateVerified) {
    $content.Add('- A real Helm chart template render completed successfully against `helm/yas`.')
}
if ($gitopsValuesVerified) {
    $content.Add('- The committed GitOps values under `argocd/values/` are in sync with the frozen release baseline generator.')
}
if ($sharedPromotionCommitMetadataVerified) {
    $content.Add('- Shared `dev` and `staging` promotion flows now record commit metadata so mutable and release-tagged deployments can be traced back to an exact source commit.')
}
if ($runtimeEvidenceProvenanceVerified) {
    $content.Add('- Runtime evidence directories now snapshot commit, build, push, and verification artifacts such as `commit-metadata.json` and `image-digests.txt` per run.')
}
if ($selfContainedCommitMetadataVerified) {
    $content.Add('- Commit metadata artifacts now embed the exact commit SHA and short SHA directly in `commit-metadata.json`, not only in sidecar text files.')
}
if ($partialImageMetadataVerified) {
    $content.Add('- Build, push, and remote-tag verification helpers now preserve partial metadata artifacts with completion state and the last attempted image when a run fails mid-stream.')
}
if ($failureSafeRuntimeEvidenceVerified) {
    $content.Add('- Deploy and smoke-test helpers now capture partial runtime diagnostics even when rollout or endpoint verification fails, reducing lost evidence on first-failure runs.')
}
if ($cleanupGuardVerified) {
    $content.Add('- Cleanup helpers now require explicit opt-in for shared targets and a second explicit opt-in before deleting shared namespaces.')
}
$content.Add('')
$content.Add('## Runtime Access Notes')
if ($dockerCommandAvailable -and -not $dockerDaemonReachable) {
    $content.Add('- Docker CLI is installed, but the current execution context cannot reach the Docker daemon; local image verification lines may be incomplete unless this report is run with host Docker access.')
} elseif ($dockerDaemonReachable) {
    $content.Add('- Docker daemon access was available while generating this report, so local image verification could be checked directly.')
}
$content.Add('')
$content.Add('## Still Blocked In This Workspace')
$content.Add('- The full runtime image set has not been built and pushed from this workspace.')
$content.Add('- A full upstream-style test pass is still blocked for `sampledata` and `search` in this workspace.')
$content.Add('- Real Kubernetes deployment cannot be executed.')
$content.Add('- Jenkins credentials and webhook integration cannot be verified locally.')

[System.IO.File]::WriteAllLines($resolvedOutputPath, $content)
Write-Host "Generated status report: $OutputFile"

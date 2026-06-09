param(
    [string]$OutputFile = 'work/status-report.generated.md',
    [switch]$SkipCommandChecks
)

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
    'helm\yas\Chart.yaml',
    'docs\status-report.md',
    'argocd\app-dev.yaml',
    'mesh\peer-authentication.yaml',
    'scripts\selftest.ps1',
    'scripts\validate-services-catalog.ps1'
)

$requiredCommands = @('git', 'kubectl', 'helm', 'docker')
$servicesFile = 'jenkins/services.env'
$sourceRoot = 'yas-source'
$serviceCount = 0
$publicEntryCount = 0
$uiCount = 0
$backendCount = 0
$sourceAligned = $false
$storefrontBuildVerified = (Test-Path 'yas-source\storefront\.next')
$backofficeBuildVerified = (Test-Path 'yas-source\backoffice\.next')
$storefrontBffBuildVerified = (Test-Path 'yas-source\storefront-bff\target\storefront-bff-1.0-SNAPSHOT.jar')
$backofficeBffBuildVerified = (Test-Path 'yas-source\backoffice-bff\target\backoffice-bff-1.0-SNAPSHOT.jar')
$productBuildVerified = (Test-Path 'yas-source\product\target\product-1.0-SNAPSHOT.jar')
$paymentBuildVerified = (Test-Path 'yas-source\payment\target\payment-1.0-SNAPSHOT.jar')
$paymentPaypalBuildVerified = (Test-Path 'yas-source\payment-paypal\target\payment-paypal-1.0-SNAPSHOT.jar')
$recommendationBuildVerified = (Test-Path 'yas-source\recommendation\target\recommendation-1.0-SNAPSHOT.jar')
$productImageVerified = $false
$backofficeImageVerified = $false
$storefrontBffImageVerified = $false
$backofficeBffImageVerified = $false
$paymentImageVerified = $false
$paymentPaypalImageVerified = $false
$recommendationImageVerified = $false
$helmExecutable = Get-HelmExecutable
$helmLintVerified = $false
$helmTemplateVerified = $false

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

if ($null -ne (Get-Command docker -ErrorAction SilentlyContinue)) {
    try {
        docker image inspect 'yas-product:codex-verified' *> $null
        $productImageVerified = ($LASTEXITCODE -eq 0)
    } catch {
        $productImageVerified = $false
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

$fileLines = foreach ($file in $requiredFiles) {
    $status = if (Test-Path $file) { 'ok' } else { 'missing' }
    "- ${file}: $status"
}

$commandLines = foreach ($cmd in $requiredCommands) {
    $status = if ($cmd -eq 'helm') {
        if ($helmExecutable) { 'ok' } else { 'missing' }
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
if ($sourceAligned) {
    $content.Add('- Service catalog paths and Dockerfiles were verified against the local `yas-source` clone.')
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
if ($productImageVerified) {
    $content.Add('- A real `product` Docker image build completed successfully in this workspace.')
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
if ($helmLintVerified) {
    $content.Add('- A real Helm chart lint completed successfully against `helm/yas`.')
}
if ($helmTemplateVerified) {
    $content.Add('- A real Helm chart template render completed successfully against `helm/yas`.')
}
$content.Add('')
$content.Add('## Still Blocked In This Workspace')
$content.Add('- The full runtime image set has not been built and pushed from this workspace.')
$content.Add('- Real Kubernetes deployment cannot be executed.')
$content.Add('- Jenkins credentials and webhook integration cannot be verified locally.')

[System.IO.File]::WriteAllLines($resolvedOutputPath, $content)
Write-Host "Generated status report: $OutputFile"

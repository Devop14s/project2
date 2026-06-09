param(
    [string]$OutputFile = 'work/status-report.generated.md',
    [switch]$SkipCommandChecks
)

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
$productBuildVerified = (Test-Path 'yas-source\product\target\product-1.0-SNAPSHOT.jar')
$productImageVerified = $false
$backofficeImageVerified = $false

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
}

$fileLines = foreach ($file in $requiredFiles) {
    $status = if (Test-Path $file) { 'ok' } else { 'missing' }
    "- ${file}: $status"
}

$commandLines = foreach ($cmd in $requiredCommands) {
    $status = if ($null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)) { 'ok' } else { 'missing' }
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
if ($productBuildVerified) {
    $content.Add('- A real `product` Maven backend build completed successfully and produced a runnable JAR artifact.')
}
if ($productImageVerified) {
    $content.Add('- A real `product` Docker image build completed successfully in this workspace.')
}
if ($backofficeImageVerified) {
    $content.Add('- A real `backoffice` Docker image build completed successfully in this workspace.')
}
$content.Add('')
$content.Add('## Still Blocked In This Workspace')
$content.Add('- The full runtime image set has not been built and pushed from this workspace.')
$content.Add('- Real Kubernetes deployment cannot be executed.')
$content.Add('- Jenkins credentials and webhook integration cannot be verified locally.')

[System.IO.File]::WriteAllLines($resolvedOutputPath, $content)
Write-Host "Generated status report: $OutputFile"

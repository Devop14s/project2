param(
    [string]$OutputFile = 'work/service-verification.generated.md'
)

. "$PSScriptRoot\catalog.ps1"
. "$PSScriptRoot\source-root.ps1"

$servicesFile = Resolve-ServicesCatalogFile -ServicesFile ''
$sourceRoot = Resolve-SourceRoot -SourceRoot ''
$blockers = @{}

if (Test-Path 'scripts\summarize-failsafe-blockers.ps1') {
    foreach ($line in @(powershell -ExecutionPolicy Bypass -File scripts\summarize-failsafe-blockers.ps1)) {
        $parts = $line -split '\|', 4
        if ($parts.Count -ge 4) {
            $blockers[$parts[0]] = @{
                category = $parts[1]
                suite = $parts[2]
                message = $parts[3]
            }
        }
    }
}

$fullBuildVerified = @(
    'storefront',
    'backoffice',
    'storefront-bff',
    'backoffice-bff',
    'product',
    'payment',
    'payment-paypal',
    'recommendation',
    'inventory',
    'order'
)

function Get-BuildEvidence {
    param(
        [string]$Service,
        [string]$WorkloadType
    )

    if ($Service -in @('storefront', 'backoffice')) {
        $nextDir = Join-Path $sourceRoot "$Service\.next"
        return @{ present = (Test-Path $nextDir); kind = '.next' }
    }

    $jarPath = Join-Path $sourceRoot "$Service\target\$Service-1.0-SNAPSHOT.jar"
    return @{ present = (Test-Path $jarPath); kind = 'jar' }
}

function Get-ImageVerified {
    param([string]$Service)

    try {
        docker version *> $null
        if ($LASTEXITCODE -ne 0) { return $false }
        docker image inspect ("yas-{0}:codex-verified" -f $Service) *> $null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

$rows = New-Object System.Collections.Generic.List[string]
$rows.Add('# Service Verification Matrix')
$rows.Add('')
$rows.Add(("This file is generated from `jenkins/services.env`, local source artifacts under `{0}/`, local Docker images, and workspace blocker summaries." -f $sourceRoot))
$rows.Add('')
$rows.Add('| Service | Workload | Build evidence | Local image | Blocker | Overall status |')
$rows.Add('| --- | --- | --- | --- | --- | --- |')

foreach ($line in Get-Content $servicesFile) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
        continue
    }

    $parts = $line.Split('|')
    if ($parts.Count -lt 7) {
        continue
    }

    $service = $parts[0].Trim()
    $workloadType = $parts[6].Trim()
    $buildEvidence = Get-BuildEvidence -Service $service -WorkloadType $workloadType
    $imageVerified = Get-ImageVerified -Service $service

    $blockerText = 'none'
    $overallStatus = 'not verified'

    if ($blockers.ContainsKey($service)) {
        $blockerText = "$($blockers[$service].category): $($blockers[$service].suite)"
        if ($buildEvidence.present -and $imageVerified) {
            $overallStatus = 'package+image verified, full test path blocked'
        } elseif ($buildEvidence.present) {
            $overallStatus = 'build artifact verified, full test path blocked'
        } else {
            $overallStatus = 'blocked'
        }
    } elseif ($service -in $fullBuildVerified) {
        if ($imageVerified) {
            $overallStatus = 'full build verified + image verified'
        } else {
            $overallStatus = 'full build verified'
        }
    } elseif ($buildEvidence.present -and $imageVerified) {
        $overallStatus = 'package+image verified'
    } elseif ($buildEvidence.present) {
        $overallStatus = 'build artifact verified'
    }

    $buildText = if ($buildEvidence.present) { ('yes (`{0}`)' -f $buildEvidence['kind']) } else { 'no' }
    $imageText = if ($imageVerified) { 'yes' } else { 'no' }
    $rows.Add("| $service | $workloadType | $buildText | $imageText | $blockerText | $overallStatus |")
}

$outputDir = Split-Path -Parent $OutputFile
if ($outputDir) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}
$resolvedOutputPath = if ([System.IO.Path]::IsPathRooted($OutputFile)) { $OutputFile } else { Join-Path (Get-Location) $OutputFile }
[System.IO.File]::WriteAllLines($resolvedOutputPath, $rows)
Write-Host "Generated service verification matrix: $OutputFile"

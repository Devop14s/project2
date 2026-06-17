param(
    [string]$StatusReportFile = 'work/status-report.generated.md',
    [string]$ServiceVerificationFile = 'work/service-verification.generated.md',
    [string]$HostCapabilitiesFile = 'work/host-capabilities.generated.md',
    [string]$ServicesFile = 'jenkins/services.env',
    [string]$ReleaseBaselineServicesFile = 'jenkins/services.release-baseline.env'
)

foreach ($requiredFile in @($StatusReportFile, $ServiceVerificationFile, $HostCapabilitiesFile, $ServicesFile, $ReleaseBaselineServicesFile)) {
    if (-not (Test-Path $requiredFile)) {
        throw "Required file not found: $requiredFile"
    }
}

$statusText = Get-Content $StatusReportFile -Raw -ErrorAction Stop
$serviceVerificationText = Get-Content $ServiceVerificationFile -Raw -ErrorAction Stop
$hostCapabilitiesText = Get-Content $HostCapabilitiesFile -Raw -ErrorAction Stop

$serviceCount = 0
$releaseBaselineServiceCount = 0
$publicEntryCount = 0
$uiCount = 0
$backendCount = 0
$services = New-Object System.Collections.Generic.List[string]

foreach ($line in Get-Content $ServicesFile) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
        continue
    }

    $parts = $line.Split('|')
    if ($parts.Count -lt 7) {
        continue
    }

    $service = $parts[0].Trim()
    $expose = $parts[4].Trim()
    $workloadType = $parts[6].Trim()

    $services.Add($service)
    $serviceCount += 1
    if ($expose -eq 'true') {
        $publicEntryCount += 1
    }
    if ($workloadType -eq 'ui') {
        $uiCount += 1
    } elseif ($workloadType -eq 'backend') {
        $backendCount += 1
    }
}

foreach ($line in Get-Content $ReleaseBaselineServicesFile) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
        continue
    }

    $parts = $line.Split('|')
    if ($parts.Count -ge 7) {
        $releaseBaselineServiceCount += 1
    }
}

foreach ($requiredStatusToken in @(
    '# Generated Status Report',
    "- Services in catalog: $serviceCount",
    "- Services in release baseline: $releaseBaselineServiceCount",
    "- Public entrypoints in catalog: $publicEntryCount",
    "- UI workloads in catalog: $uiCount",
    "- Backend workloads in catalog: $backendCount",
    'Drift validators now lock the main hand-written docs and runbooks',
    'A machine-generated host capability snapshot now records which tools and runtime dependencies were actually reachable while this local evidence bundle was produced.',
    'Real Kubernetes deployment cannot be executed.',
    'Jenkins credentials and webhook integration cannot be verified locally.'
)) {
    if (-not $statusText.Contains($requiredStatusToken)) {
        throw "Generated status report is missing required token $requiredStatusToken."
    }
}

foreach ($service in $services) {
    $rowToken = "| $service |"
    if (-not $serviceVerificationText.Contains($rowToken)) {
        throw "Generated service verification matrix is missing row for service $service."
    }
}

foreach ($requiredServiceMatrixToken in @(
    '# Service Verification Matrix',
    '| Service | Workload | Build evidence | Local image | Blocker | Overall status |',
    '| storefront | ui |',
    '| backoffice | ui |',
    '| product | backend |',
    '| sampledata | backend |',
    '| search | backend |',
    'keycloak:',
    'elasticsearch:',
    'compile:',
    'full build verified',
    '| blocked |'
)) {
    if (-not $serviceVerificationText.Contains($requiredServiceMatrixToken)) {
        throw "Generated service verification matrix is missing required token $requiredServiceMatrixToken."
    }
}

foreach ($requiredHostToken in @(
    '# Host Capabilities Report',
    '## Tool Availability',
    '## Runtime Reachability',
    '## Workspace Inputs',
    '## Generated Evidence Snapshot',
    '## Interpretation',
    '`git`:',
    '`docker`:',
    '`kubectl`:',
    '`helm`:',
    '`java`:',
    '`mvn`:',
    '`node`:',
    '`npm`:',
    '`powershell`:',
    '`sh`:',
    'work/status-report.generated.md',
    'work/service-verification.generated.md',
    'work/final-report-notes.generated.md'
)) {
    if (-not $hostCapabilitiesText.Contains($requiredHostToken)) {
        throw "Generated host capabilities report is missing required token $requiredHostToken."
    }
}

$blockerLines = @(powershell -ExecutionPolicy Bypass -File scripts\summarize-failsafe-blockers.ps1)
foreach ($blockerLine in $blockerLines) {
    $parts = $blockerLine -split '\|', 4
    if ($parts.Count -lt 3) {
        continue
    }

    $service = $parts[0]
    $category = $parts[1]
    $suite = $parts[2]
    $expectedBlockerToken = "${category}: $suite"
    if (-not $serviceVerificationText.Contains("| $service |")) {
        throw "Generated service verification matrix is missing blocker row for service $service."
    }
    if (-not $serviceVerificationText.Contains($expectedBlockerToken)) {
        throw "Generated service verification matrix is missing blocker token $expectedBlockerToken for service $service."
    }
}

Write-Host 'Generated status, service-verification, and host-capabilities reports are aligned with the current catalog, validator coverage, and blocker summary.'

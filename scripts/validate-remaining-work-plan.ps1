param(
    [string]$PlanFile = 'docs/remaining-work-plan.md'
)

$planText = Get-Content $PlanFile -Raw
$baselineServicesFile = 'jenkins/services.release-baseline.env'
$blockerLines = @(powershell -ExecutionPolicy Bypass -File scripts\summarize-failsafe-blockers.ps1)

foreach ($line in Get-Content $baselineServicesFile) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
        continue
    }

    $service = $line.Split('|')[0].Trim()
    $serviceToken = '`' + $service + '`'
    if (-not $planText.Contains($serviceToken)) {
        throw "docs/remaining-work-plan.md is missing frozen baseline service $serviceToken."
    }
}

foreach ($blockerLine in $blockerLines) {
    $parts = $blockerLine -split '\|', 4
    if ($parts.Count -lt 4) {
        continue
    }

    $service = $parts[0]
    $serviceToken = '`' + $service + '`'
    if (-not $planText.Contains($serviceToken)) {
        throw "docs/remaining-work-plan.md is missing blocker service $serviceToken."
    }
}

foreach ($requiredReference in @(
    'jenkins/services.release-baseline.env',
    'status-report.md',
    'work/service-verification.generated.md'
)) {
    if ($planText -notmatch [regex]::Escape($requiredReference)) {
        throw "docs/remaining-work-plan.md should reference $requiredReference."
    }
}

Write-Host 'docs/remaining-work-plan.md is aligned with the frozen baseline and current blocker set.'

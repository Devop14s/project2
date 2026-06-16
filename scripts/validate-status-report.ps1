param(
    [string]$StatusReport = 'docs/status-report.md'
)

$statusText = Get-Content $StatusReport -Raw
$blockerLines = @(powershell -ExecutionPolicy Bypass -File scripts\summarize-failsafe-blockers.ps1)

$requiredFullBuildServices = @(
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

foreach ($service in $requiredFullBuildServices) {
    $serviceToken = '`' + $service + '`'
    if (-not $statusText.Contains($serviceToken)) {
        throw "docs/status-report.md is missing verified service $serviceToken."
    }
}

foreach ($blockerLine in $blockerLines) {
    $parts = $blockerLine -split '\|', 4
    if ($parts.Count -lt 4) {
        continue
    }

    $service = $parts[0]
    $serviceToken = '`' + $service + '`'
    if (-not $statusText.Contains($serviceToken)) {
        throw "docs/status-report.md is missing blocker service $serviceToken."
    }
}

if ($statusText -notmatch [regex]::Escape('work/service-verification.generated.md')) {
    throw 'docs/status-report.md should reference the generated service verification matrix.'
}

if ($statusText -notmatch [regex]::Escape('remaining-work-plan.md')) {
    throw 'docs/status-report.md should still point to remaining-work-plan.md.'
}

if ($statusText -notmatch [regex]::Escape('work/final-report-notes.generated.md')) {
    throw 'docs/status-report.md should reference work/final-report-notes.generated.md.'
}

if ($statusText -notmatch [regex]::Escape('scripts\refresh-evidence.ps1 -SkipCommandChecks')) {
    throw 'docs/status-report.md should point to scripts\refresh-evidence.ps1 -SkipCommandChecks as the evidence refresh entrypoint.'
}

Write-Host 'docs/status-report.md is aligned with the current blocker and verification summary.'

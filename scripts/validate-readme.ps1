param(
    [string]$ReadmeFile = 'README.md'
)

$readmeText = Get-Content $ReadmeFile -Raw

foreach ($requiredToken in @(
    'docs/status-report.md',
    'docs/remaining-work-plan.md',
    'work/service-verification.generated.md',
    'work/final-report-notes.generated.md',
    'work/host-capabilities.generated.md',
    'scripts\refresh-evidence.ps1 -SkipCommandChecks',
    'jenkins/services.release-baseline.env',
    '`storefront`',
    '`backoffice`',
    '`product`',
    '`payment`',
    '`inventory`',
    '`order`',
    '`cart`',
    '`customer`',
    '`location`',
    '`media`',
    '`promotion`',
    '`rating`',
    '`tax`',
    '`webhook`',
    '`sampledata`',
    '`search`'
)) {
    if (-not $readmeText.Contains($requiredToken)) {
        throw "README.md is missing required token $requiredToken."
    }
}

Write-Host 'README.md is aligned with the current verified scope, baseline catalog, and generated evidence references.'

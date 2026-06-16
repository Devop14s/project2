param(
    [string]$TroubleshootingFile = 'docs/troubleshooting.md'
)

$troubleshootingText = Get-Content $TroubleshootingFile -Raw
$blockerLines = @(powershell -ExecutionPolicy Bypass -File scripts\summarize-failsafe-blockers.ps1)

foreach ($blockerLine in $blockerLines) {
    $parts = $blockerLine -split '\|', 4
    if ($parts.Count -lt 4) {
        continue
    }

    $service = $parts[0]
    $serviceToken = '`' + $service + '`'
    if (-not $troubleshootingText.Contains($serviceToken)) {
        throw "docs/troubleshooting.md is missing blocker service $serviceToken."
    }
}

foreach ($requiredToken in @(
    'Docker push authentication failure',
    'Helm upgrade fails',
    'NodePort is open but app is unreachable',
    'Keycloak',
    'Elasticsearch',
    'work/service-verification.generated.md'
)) {
    if (-not $troubleshootingText.Contains($requiredToken)) {
        throw "docs/troubleshooting.md is missing required troubleshooting topic $requiredToken."
    }
}

Write-Host 'docs/troubleshooting.md is aligned with the current workspace blocker set and runtime troubleshooting topics.'

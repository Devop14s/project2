param(
    [string]$ReadmeFile = 'mesh/README.md'
)

$readmeText = Get-Content $ReadmeFile -Raw

foreach ($requiredToken in @(
    '`peer-authentication.yaml`',
    '`destination-rule.yaml`',
    '`virtual-service-retry.yaml`',
    '`authorization-policy.yaml`',
    '`kiali-access.md`',
    'service-mesh-test-plan.md',
    'service-mesh-results.md'
)) {
    if (-not $readmeText.Contains($requiredToken)) {
        throw "mesh/README.md is missing required token $requiredToken."
    }
}

Write-Host 'mesh/README.md is aligned with the current service-mesh scaffold files and supporting docs.'

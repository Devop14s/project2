param(
    [string]$MatrixFile = 'docs/source-build-runtime-matrix.md'
)

. "$PSScriptRoot\catalog.ps1"

$matrixText = Get-Content $MatrixFile -Raw
$servicesFile = Resolve-ServicesCatalogFile -ServicesFile ''
$blockerLines = @(powershell -ExecutionPolicy Bypass -File scripts\summarize-failsafe-blockers.ps1)

foreach ($line in Get-Content $servicesFile) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
        continue
    }

    $service = $line.Split('|')[0].Trim()
    $serviceToken = '`' + $service + '`'
    if (-not $matrixText.Contains($serviceToken)) {
        throw "docs/source-build-runtime-matrix.md is missing service $serviceToken."
    }
}

foreach ($blockerLine in $blockerLines) {
    $parts = $blockerLine -split '\|', 4
    if ($parts.Count -lt 4) {
        continue
    }

    $serviceToken = '`' + $parts[0] + '`'
    if (-not $matrixText.Contains($serviceToken)) {
        throw "docs/source-build-runtime-matrix.md is missing blocker service $serviceToken."
    }
}

if (-not $matrixText.Contains('`helm lint helm/yas`')) {
    throw 'docs/source-build-runtime-matrix.md should mention `helm lint helm/yas`.'
}

if (-not $matrixText.Contains('`helm template yas helm/yas`')) {
    throw 'docs/source-build-runtime-matrix.md should mention `helm template yas helm/yas`.'
}

Write-Host 'docs/source-build-runtime-matrix.md covers the current catalog and blocker summary.'

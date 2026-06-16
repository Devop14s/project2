param(
    [string]$MatrixFile = 'docs/image-matrix.md'
)

. "$PSScriptRoot\catalog.ps1"

$matrixText = Get-Content $MatrixFile -Raw
$servicesFile = Resolve-ServicesCatalogFile -ServicesFile ''

foreach ($line in Get-Content $servicesFile) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
        continue
    }

    $service = $line.Split('|')[0].Trim()
    $serviceToken = '| ' + $service + ' |'
    if (-not $matrixText.Contains($serviceToken)) {
        throw "docs/image-matrix.md is missing table row for service $service."
    }
}

foreach ($blockedService in @('sampledata', 'search')) {
    $pattern = [regex]::Escape('| ' + $blockedService + ' |') + '.*blocked'
    if ($matrixText -notmatch $pattern) {
        throw "docs/image-matrix.md should note that $blockedService still has a blocked full test path."
    }
}

if (-not $matrixText.Contains('work/service-verification.generated.md')) {
    throw 'docs/image-matrix.md should reference the generated service verification matrix.'
}

if (-not $matrixText.Contains('work/host-capabilities.generated.md')) {
    throw 'docs/image-matrix.md should reference the generated host capabilities snapshot.'
}

if (-not $matrixText.Contains('scripts\refresh-evidence.ps1 -SkipCommandChecks')) {
    throw 'docs/image-matrix.md should point to scripts\refresh-evidence.ps1 -SkipCommandChecks as the evidence refresh entrypoint.'
}

Write-Host 'docs/image-matrix.md covers the current catalog and blocked-image notes.'

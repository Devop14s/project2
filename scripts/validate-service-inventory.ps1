param(
    [string]$InventoryFile = 'docs/service-inventory.md'
)

$inventoryText = Get-Content $InventoryFile -Raw
$fullCatalog = 'jenkins/services.env'
$baselineCatalog = 'jenkins/services.release-baseline.env'

$baselineServices = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($line in Get-Content $baselineCatalog) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
        continue
    }

    $service = $line.Split('|')[0].Trim()
    if (-not [string]::IsNullOrWhiteSpace($service)) {
        $null = $baselineServices.Add($service)
    }
}

foreach ($line in Get-Content $fullCatalog) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
        continue
    }

    $parts = $line.Split('|')
    if ($parts.Count -lt 7) {
        continue
    }

    $service = $parts[0].Trim()
    $path = $parts[1].Trim()
    $dockerfile = $parts[2].Trim()
    $port = $parts[3].Trim()
    $expose = $parts[4].Trim()
    $nodePort = $parts[5].Trim()
    $workloadType = $parts[6].Trim()
    $recommended = if ($baselineServices.Contains($service)) { 'yes' } else { 'no' }

    $serviceRow = ($inventoryText -split "`r?`n" | Where-Object { $_ -match ('^\| ' + [regex]::Escape($service) + ' \|') } | Select-Object -First 1)
    if ([string]::IsNullOrWhiteSpace($serviceRow)) {
        throw "docs/service-inventory.md is missing row for service $service."
    }

    foreach ($requiredToken in @(
        ('| `' + $path + '` |'),
        ('| `' + $dockerfile + '` |'),
        ('| `' + $port + '` |'),
        ('| `' + $workloadType + '` |'),
        '| ' + $recommended + ' |'
    )) {
        if (-not $serviceRow.Contains($requiredToken)) {
            throw "docs/service-inventory.md is missing expected token $requiredToken for service $service."
        }
    }

    if ($expose -eq 'true') {
        $nodePortToken = '| `' + $nodePort + '` |'
        if (-not $serviceRow.Contains($nodePortToken)) {
            throw "docs/service-inventory.md is missing expected nodePort token $nodePortToken for service $service."
        }
    }
}

foreach ($requiredReference in @(
    'jenkins/services.release-baseline.env',
    'jenkins/services.env',
    'work/service-verification.generated.md',
    'work/host-capabilities.generated.md',
    'scripts\refresh-evidence.ps1 -SkipCommandChecks'
)) {
    if ($inventoryText -notmatch [regex]::Escape($requiredReference)) {
        throw "docs/service-inventory.md should reference $requiredReference."
    }
}

Write-Host 'docs/service-inventory.md is aligned with the full catalog, frozen baseline, and generated verification snapshot.'

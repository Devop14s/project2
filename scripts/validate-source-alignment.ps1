param(
    [string]$ServicesFile = 'jenkins/services.env',
    [string]$SourceRoot = 'yas-source'
)

if (-not (Test-Path $ServicesFile)) {
    Write-Error "Services file not found: $ServicesFile"
    exit 1
}

if (-not (Test-Path $SourceRoot)) {
    Write-Error "Source root not found: $SourceRoot"
    exit 1
}

$errors = New-Object System.Collections.Generic.List[string]
$lineNumber = 0

foreach ($line in Get-Content $ServicesFile) {
    $lineNumber += 1
    if (-not $line) { continue }
    if ($line.StartsWith('#')) { continue }

    $parts = $line.Split('|')
    if ($parts.Count -lt 3) { continue }

    $service = $parts[0]
    $path = $parts[1]
    $dockerfile = $parts[2]

    $resolvedPath = Join-Path $SourceRoot $path
    $resolvedDockerfile = Join-Path $SourceRoot $dockerfile

    if (-not (Test-Path $resolvedPath)) {
        $errors.Add("Line $lineNumber service '$service' path not found in source: $resolvedPath")
    }

    if (-not (Test-Path $resolvedDockerfile)) {
        $errors.Add("Line $lineNumber service '$service' Dockerfile not found in source: $resolvedDockerfile")
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    exit 1
}

Write-Host "Service catalog matches source tree: $SourceRoot"

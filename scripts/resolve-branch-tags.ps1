param(
    [string]$ServicesFile = 'jenkins/services.env',
    [string]$OutputFile = 'work/branch-tags.env'
)

if (-not (Test-Path $ServicesFile)) {
    Write-Error "Services file not found: $ServicesFile"
    exit 1
}

$outputDir = Split-Path -Parent $OutputFile
if ($outputDir) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$resolvedOutputPath = if ([System.IO.Path]::IsPathRooted($OutputFile)) {
    $OutputFile
} else {
    Join-Path (Get-Location) $OutputFile
}

$lines = Get-Content $ServicesFile
$output = New-Object System.Collections.Generic.List[string]

function Get-BranchEnvName {
    param([string]$ServiceName)
    return (($ServiceName.ToUpper() -replace '-', '_') + '_BRANCH')
}

function Get-TagEnvName {
    param([string]$ServiceName)
    return (($ServiceName.ToUpper() -replace '-', '_') + '_TAG')
}

function Resolve-Tag {
    param([string]$Branch)

    if ($Branch -eq 'main') {
        return 'main'
    }

    & git rev-parse --verify "origin/$Branch" *> $null
    if ($LASTEXITCODE -eq 0) {
        return (& git rev-parse "origin/$Branch").Trim()
    }

    & git rev-parse --verify $Branch *> $null
    if ($LASTEXITCODE -eq 0) {
        return (& git rev-parse $Branch).Trim()
    }

    throw "Unable to resolve branch: $Branch"
}

foreach ($line in $lines) {
    if (-not $line) { continue }
    if ($line.StartsWith('#')) { continue }

    $parts = $line.Split('|')
    $service = $parts[0]
    if (-not $service) { continue }

    $branchVar = Get-BranchEnvName -ServiceName $service
    $branchValue = [Environment]::GetEnvironmentVariable($branchVar)
    if ([string]::IsNullOrWhiteSpace($branchValue)) {
        $branchValue = 'main'
    }

    $tagVar = Get-TagEnvName -ServiceName $service
    $tagValue = Resolve-Tag -Branch $branchValue
    $output.Add("$tagVar=$tagValue")
}

[System.IO.File]::WriteAllLines($resolvedOutputPath, $output)
Write-Host "Resolved branch tags into $OutputFile"

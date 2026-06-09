param(
    [string]$ServicesFile = '',
    [string]$SourceGitRoot = '',
    [string]$OutputFile = 'work/branch-tags.env',
    [string]$MetadataFile = 'work/branch-tag-metadata.json'
)

. "$PSScriptRoot\catalog.ps1"
. "$PSScriptRoot\source-root.ps1"
$ServicesFile = Resolve-ServicesCatalogFile -ServicesFile $ServicesFile
$SourceGitRoot = Resolve-SourceGitRoot -SourceGitRoot $SourceGitRoot -SourceRoot ''

if (-not (Test-Path $ServicesFile)) {
    Write-Error "Services file not found: $ServicesFile"
    exit 1
}

$outputDir = Split-Path -Parent $OutputFile
if ($outputDir) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$metadataDir = Split-Path -Parent $MetadataFile
if ($metadataDir) {
    New-Item -ItemType Directory -Path $metadataDir -Force | Out-Null
}

$resolvedOutputPath = if ([System.IO.Path]::IsPathRooted($OutputFile)) {
    $OutputFile
} else {
    Join-Path (Get-Location) $OutputFile
}

$resolvedMetadataPath = if ([System.IO.Path]::IsPathRooted($MetadataFile)) {
    $MetadataFile
} else {
    Join-Path (Get-Location) $MetadataFile
}

$lines = Get-Content $ServicesFile
$output = New-Object System.Collections.Generic.List[string]
$metadataEntries = New-Object System.Collections.Generic.List[object]

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

    & git -C $SourceGitRoot rev-parse --verify "origin/$Branch" *> $null
    if ($LASTEXITCODE -eq 0) {
        return (& git -C $SourceGitRoot rev-parse "origin/$Branch").Trim()
    }

    & git -C $SourceGitRoot rev-parse --verify $Branch *> $null
    if ($LASTEXITCODE -eq 0) {
        return (& git -C $SourceGitRoot rev-parse $Branch).Trim()
    }

    throw "Unable to resolve branch in ${SourceGitRoot}: $Branch"
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
    $metadataEntries.Add([pscustomobject]@{
        service = $service
        branch = $branchValue
        tag = $tagValue
    })
}

[System.IO.File]::WriteAllLines($resolvedOutputPath, $output)
$metadata = [pscustomobject]@{
    services_file = $ServicesFile
    source_git_root = $SourceGitRoot
    output_file = $OutputFile
    generated_at = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    entries = $metadataEntries
}
$metadata | ConvertTo-Json -Depth 4 | Set-Content -Path $resolvedMetadataPath
Write-Host "Resolved branch tags into $OutputFile"

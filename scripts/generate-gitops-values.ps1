param(
    [string]$ServicesFile = 'jenkins/services.env',
    [string]$TagsFile = '',
    [string]$OutputFile = 'work/gitops-values.yaml',
    [string]$EnvironmentName = 'dev',
    [string]$NamespaceName = '',
    [string]$DomainName = '',
    [string]$ReleaseVersion = 'main'
)

if (-not (Test-Path $ServicesFile)) {
    Write-Error "Services file not found: $ServicesFile"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($NamespaceName)) {
    $NamespaceName = "yas-$EnvironmentName"
}

if ([string]::IsNullOrWhiteSpace($DomainName)) {
    $DomainName = "storefront-$EnvironmentName.yas.local"
}

$tagMap = @{}
if (-not [string]::IsNullOrWhiteSpace($TagsFile) -and (Test-Path $TagsFile)) {
    foreach ($line in Get-Content $TagsFile) {
        if (-not $line) { continue }
        $parts = $line.Split('=', 2)
        if ($parts.Count -eq 2) {
            $tagMap[$parts[0]] = $parts[1]
        }
    }
}

function Get-TagEnvName {
    param([string]$ServiceName)
    return (($ServiceName.ToUpper() -replace '-', '_') + '_TAG')
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

$out = New-Object System.Collections.Generic.List[string]
$out.Add('global:')
$out.Add("  environment: $EnvironmentName")
$out.Add("  namespace: $NamespaceName")
$out.Add("  domainName: $DomainName")
$out.Add('')
$out.Add('services:')

foreach ($line in Get-Content $ServicesFile) {
    if (-not $line) { continue }
    if ($line.StartsWith('#')) { continue }

    $parts = $line.Split('|')
    $service = $parts[0]

    $tagVar = Get-TagEnvName -ServiceName $service
    $tagValue = if ($tagMap.ContainsKey($tagVar)) { $tagMap[$tagVar] } else { $ReleaseVersion }

    $out.Add("  ${service}:")
    $out.Add('    image:')
    $out.Add("      tag: $tagValue")
}

[System.IO.File]::WriteAllLines($resolvedOutputPath, $out)
Write-Host "Generated $OutputFile"

param(
    [string]$ServicesFile = 'jenkins/services.env',
    [string]$TagsFile = 'work/branch-tags.env',
    [string]$OutputFile = 'work/generated-values.yaml',
    [string]$EnvironmentName = 'developer',
    [string]$DeployerId = 'dev1',
    [string]$DomainName = '',
    [string]$NamespaceName = '',
    [string]$ReleaseName = '',
    [string]$ReleaseVersion = 'main',
    [string]$DockerhubNamespace = ''
)

if (-not (Test-Path $ServicesFile)) {
    Write-Error "Services file not found: $ServicesFile"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($DockerhubNamespace)) {
    $DockerhubNamespace = $env:DOCKERHUB_NAMESPACE
}

if ([string]::IsNullOrWhiteSpace($DockerhubNamespace)) {
    Write-Error 'Missing DockerhubNamespace or DOCKERHUB_NAMESPACE'
    exit 1
}

if ([string]::IsNullOrWhiteSpace($DomainName)) {
    $DomainName = "storefront-$DeployerId.yas.local"
}

if ([string]::IsNullOrWhiteSpace($NamespaceName)) {
    $NamespaceName = "yas-user-$DeployerId"
}

if ([string]::IsNullOrWhiteSpace($ReleaseName)) {
    $ReleaseName = "yas-$DeployerId"
}

$tagMap = @{}
if (Test-Path $TagsFile) {
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
$out.Add("  releaseName: $ReleaseName")
$out.Add('')
$out.Add('services:')

foreach ($line in Get-Content $ServicesFile) {
    if (-not $line) { continue }
    if ($line.StartsWith('#')) { continue }

    $parts = $line.Split('|')
    $service = $parts[0]
    $port = $parts[3]
    $expose = $parts[4]
    $nodePort = if ($parts.Count -ge 6) { $parts[5] } else { '' }
    $workloadType = if ($parts.Count -ge 7 -and -not [string]::IsNullOrWhiteSpace($parts[6])) { $parts[6] } else { 'backend' }

    $tagVar = Get-TagEnvName -ServiceName $service
    $tagValue = if ($tagMap.ContainsKey($tagVar)) { $tagMap[$tagVar] } else { $ReleaseVersion }
    $serviceType = if ($expose -eq 'true') { 'NodePort' } else { 'ClusterIP' }

    $out.Add("  ${service}:")
    $out.Add('    enabled: true')
    $out.Add("    workloadType: $workloadType")
    $out.Add('    image:')
    $out.Add("      repository: $DockerhubNamespace/yas-$service")
    $out.Add("      tag: $tagValue")
    $out.Add('      pullPolicy: IfNotPresent')
    $out.Add("    containerPort: $port")
    $out.Add('    service:')
    $out.Add("      type: $serviceType")
    $out.Add("      port: $port")

    if ($workloadType -eq 'backend') {
        $out.Add('    metricPort: 8090')
    }

    if ($expose -eq 'true') {
        if ([string]::IsNullOrWhiteSpace($nodePort)) {
            $nodePort = '32080'
        }
        $out.Add("      nodePort: $nodePort")
        $out.Add('    ingress:')
        $out.Add('      enabled: true')
        $out.Add("      host: $DomainName")
    }
}

[System.IO.File]::WriteAllLines($resolvedOutputPath, $out)
Write-Host "Generated $OutputFile"

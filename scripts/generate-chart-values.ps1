param(
    [string]$ServicesFile = 'jenkins/services.env',
    [string]$OutputFile = 'helm/yas/values.yaml',
    [string]$EnvironmentName = 'default',
    [string]$NamespaceName = 'default',
    [string]$DomainName = 'yas.local',
    [string]$ImageRegistryNamespace = 'docker.io/example'
)

if (-not (Test-Path $ServicesFile)) {
    Write-Error "Services file not found: $ServicesFile"
    exit 1
}

function Get-IngressHost {
    param([string]$ServiceName, [string]$DomainName)

    if ($ServiceName -eq 'storefront') {
        return "storefront.$DomainName"
    }

    if ($ServiceName -eq 'backoffice') {
        return "backoffice.$DomainName"
    }

    return "$ServiceName.$DomainName"
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
    if ($parts.Count -lt 7) { continue }

    $service = $parts[0]
    $port = $parts[3]
    $expose = $parts[4]
    $nodePort = $parts[5]
    $workloadType = $parts[6]
    $serviceType = if ($expose -eq 'true') { 'NodePort' } else { 'ClusterIP' }

    $out.Add("  ${service}:")
    $out.Add('    enabled: true')
    $out.Add("    workloadType: $workloadType")
    $out.Add('    image:')
    $out.Add("      repository: $ImageRegistryNamespace/yas-$service")
    $out.Add('      tag: main')
    $out.Add('      pullPolicy: IfNotPresent')
    $out.Add("    containerPort: $port")
    if ($workloadType -eq 'backend') {
        $out.Add('    metricPort: 8090')
    }
    $out.Add('    service:')
    $out.Add("      type: $serviceType")
    $out.Add("      port: $port")

    if ($expose -eq 'true') {
        if ([string]::IsNullOrWhiteSpace($nodePort)) {
            $nodePort = '32080'
        }
        $out.Add("      nodePort: $nodePort")
        $out.Add('    ingress:')
        $out.Add('      enabled: true')
        $out.Add("      host: $(Get-IngressHost -ServiceName $service -DomainName $DomainName)")
    }

    $out.Add('')
}

if ($out[$out.Count - 1] -eq '') {
    $out.RemoveAt($out.Count - 1)
}

[System.IO.File]::WriteAllLines($resolvedOutputPath, $out)
Write-Host "Generated $OutputFile"

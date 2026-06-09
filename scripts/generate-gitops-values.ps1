param(
    [string]$ServicesFile = '',
    [string]$TagsFile = '',
    [string]$OutputFile = 'work/gitops-values.yaml',
    [string]$EnvironmentName = 'dev',
    [string]$NamespaceName = '',
    [string]$DomainName = '',
    [string]$BackofficeDomainName = '',
    [string]$ReleaseVersion = 'main',
    [string]$DockerhubNamespace = ''
)

. "$PSScriptRoot\catalog.ps1"
$ServicesFile = Resolve-ServicesCatalogFile -ServicesFile $ServicesFile
$AllServicesFile = 'jenkins/services.env'

if (-not (Test-Path $ServicesFile)) {
    Write-Error "Services file not found: $ServicesFile"
    exit 1
}

if (-not (Test-Path $AllServicesFile)) {
    Write-Error "Reference services file not found: $AllServicesFile"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($NamespaceName)) {
    $NamespaceName = "yas-$EnvironmentName"
}

if ([string]::IsNullOrWhiteSpace($DomainName)) {
    $DomainName = "storefront-$EnvironmentName.yas.local"
}

if ([string]::IsNullOrWhiteSpace($BackofficeDomainName)) {
    $BackofficeDomainName = "backoffice-$EnvironmentName.yas.local"
}

if ([string]::IsNullOrWhiteSpace($DockerhubNamespace)) {
    $DockerhubNamespace = $env:DOCKERHUB_NAMESPACE
}

if ([string]::IsNullOrWhiteSpace($DockerhubNamespace)) {
    $DockerhubNamespace = 'docker.io/example'
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

$selectedServices = @{}
foreach ($line in Get-Content $ServicesFile) {
    if (-not $line) { continue }
    if ($line.StartsWith('#')) { continue }

    $parts = $line.Split('|')
    if ($parts.Count -lt 1) { continue }
    $selectedServices[$parts[0]] = $true
}

function Get-TagEnvName {
    param([string]$ServiceName)
    return (($ServiceName.ToUpper() -replace '-', '_') + '_TAG')
}

function Get-IngressHost {
    param([string]$ServiceName)

    if ($ServiceName -eq 'storefront') {
        return $DomainName
    }

    if ($ServiceName -eq 'backoffice') {
        return $BackofficeDomainName
    }

    return "$ServiceName-$EnvironmentName.yas.local"
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

$emittedServices = @{}
foreach ($line in Get-Content $AllServicesFile) {
    if (-not $line) { continue }
    if ($line.StartsWith('#')) { continue }

    $parts = $line.Split('|')
    if ($parts.Count -lt 1) { continue }
    $service = $parts[0]
    $emittedServices[$service] = $true

    $out.Add("  ${service}:")
    if (-not $selectedServices.ContainsKey($service)) {
        $out.Add('    enabled: false')
        continue
    }

    $tagVar = Get-TagEnvName -ServiceName $service
    $tagValue = if ($tagMap.ContainsKey($tagVar)) { $tagMap[$tagVar] } else { $ReleaseVersion }
    $out.Add('    enabled: true')
    $out.Add('    image:')
    $out.Add("      repository: $DockerhubNamespace/yas-$service")
    $out.Add("      tag: $tagValue")

    if ($parts.Count -ge 5 -and $parts[4] -eq 'true') {
        $out.Add('    ingress:')
        $out.Add('      enabled: true')
        $out.Add("      host: $(Get-IngressHost -ServiceName $service)")
    }
}

foreach ($service in $selectedServices.Keys) {
    if ($emittedServices.ContainsKey($service)) {
        continue
    }

    $tagVar = Get-TagEnvName -ServiceName $service
    $tagValue = if ($tagMap.ContainsKey($tagVar)) { $tagMap[$tagVar] } else { $ReleaseVersion }
    $out.Add("  ${service}:")
    $out.Add('    enabled: true')
    $out.Add('    image:')
    $out.Add("      repository: $DockerhubNamespace/yas-$service")
    $out.Add("      tag: $tagValue")

    if ($parts.Count -ge 5 -and $parts[4] -eq 'true') {
        $out.Add('    ingress:')
        $out.Add('      enabled: true')
        $out.Add("      host: $(Get-IngressHost -ServiceName $service)")
    }
}

[System.IO.File]::WriteAllLines($resolvedOutputPath, $out)
Write-Host "Generated $OutputFile"

function Get-ServicesCatalogFileForSelection {
    param([string]$Selection)

    if ([string]::IsNullOrWhiteSpace($Selection) -or $Selection -eq 'full') {
        return 'jenkins/services.env'
    }

    if ($Selection -eq 'release-baseline') {
        return 'jenkins/services.release-baseline.env'
    }

    throw "Unsupported SERVICE_CATALOG selection: $Selection"
}

function Resolve-ServicesCatalogFile {
    param([string]$ServicesFile)

    if (-not [string]::IsNullOrWhiteSpace($ServicesFile)) {
        return $ServicesFile
    }

    return Get-ServicesCatalogFileForSelection -Selection ([Environment]::GetEnvironmentVariable('SERVICE_CATALOG'))
}

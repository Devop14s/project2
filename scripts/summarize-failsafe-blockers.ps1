param(
    [string]$OutputFile
)

. "$PSScriptRoot\catalog.ps1"
. "$PSScriptRoot\source-root.ps1"

$servicesFile = Resolve-ServicesCatalogFile -ServicesFile ''
$sourceRoot = Resolve-SourceRoot -SourceRoot ''
$overrideFile = Join-Path $PSScriptRoot 'workspace-blocker-overrides.txt'

$lines = New-Object System.Collections.Generic.List[string]
$emittedServices = New-Object 'System.Collections.Generic.HashSet[string]'

if (Test-Path $servicesFile) {
    foreach ($line in Get-Content $servicesFile) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
            continue
        }

        $parts = $line.Split('|')
        if ($parts.Count -lt 1) {
            continue
        }

        $service = $parts[0].Trim()
        if ([string]::IsNullOrWhiteSpace($service)) {
            continue
        }

        $reportDir = Join-Path $sourceRoot "$service\target\failsafe-reports"
        $summaryFile = Join-Path $reportDir 'failsafe-summary.xml'
        if (-not (Test-Path $summaryFile)) {
            continue
        }

        try {
            [xml]$summaryXml = Get-Content $summaryFile -Raw
        } catch {
            continue
        }

        $errors = [int]$summaryXml.'failsafe-summary'.errors
        $failures = [int]$summaryXml.'failsafe-summary'.failures
        if (($errors + $failures) -le 0) {
            continue
        }

        $textReports = @(Get-ChildItem -Path $reportDir -Filter '*.txt' -ErrorAction SilentlyContinue)
        if ($textReports.Count -eq 0) {
            continue
        }

        $failingReport = $textReports | Where-Object {
            (Get-Content $_.FullName -Raw) -match '<<< FAILURE!' -or
            (Get-Content $_.FullName -Raw) -match '<<< ERROR!'
        } | Select-Object -First 1
        if (-not $failingReport) {
            $failingReport = $textReports[0]
        }

        $suiteName = [System.IO.Path]::GetFileNameWithoutExtension($failingReport.Name)
        $content = ($textReports | ForEach-Object { Get-Content $_.FullName -Raw }) -join "`n"

        $category = 'unknown'
        $message = "$suiteName failed during the upstream-style integration phase."

        if ($content -match 'quay\.io/keycloak/keycloak:26\.0' -or $content -match '/health/started') {
            $category = 'keycloak'
            $message = "$suiteName failed because Keycloak Testcontainers did not become healthy on /health/started."
        } elseif ($content -match 'docker\.elastic\.co/elasticsearch/elasticsearch' -or $content -match 'ProductCdcConsumerTest' -or $content -match 'Elasticsearch') {
            $category = 'elasticsearch'
            $message = "$suiteName failed because the Elasticsearch Testcontainers dependency did not become ready."
        } elseif ($content -match 'Container startup failed for image ([^\s]+)') {
            $category = 'testcontainers'
            $message = "$suiteName failed because Testcontainers could not start image $($Matches[1])."
        } elseif ($content -match 'Failed to load ApplicationContext') {
            $category = 'spring-context'
            $message = "$suiteName failed because the Spring test ApplicationContext could not be created."
        }

        $lines.Add("$service|$category|$suiteName|$message")
        $null = $emittedServices.Add($service)
    }
}

if (Test-Path $overrideFile) {
    foreach ($overrideLine in Get-Content $overrideFile) {
        if ([string]::IsNullOrWhiteSpace($overrideLine) -or $overrideLine.StartsWith('#')) {
            continue
        }

        $parts = $overrideLine -split '\|', 4
        if ($parts.Count -lt 4) {
            continue
        }

        if ($emittedServices.Contains($parts[0])) {
            continue
        }

        $lines.Add($overrideLine)
    }
}

if ([string]::IsNullOrWhiteSpace($OutputFile)) {
    $lines
} else {
    $outputDir = Split-Path -Parent $OutputFile
    if ($outputDir) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    $resolvedOutputPath = if ([System.IO.Path]::IsPathRooted($OutputFile)) {
        $OutputFile
    } else {
        Join-Path (Get-Location) $OutputFile
    }
    [System.IO.File]::WriteAllLines($resolvedOutputPath, $lines)
}

param(
    [string]$OutputFile = 'work/host-capabilities.generated.md'
)

function Get-HelmExecutable {
    $helmCommand = Get-Command helm -ErrorAction SilentlyContinue
    if ($helmCommand) {
        return $helmCommand.Source
    }

    $localHelm = Get-ChildItem -Path 'work\tools' -Filter 'helm.exe' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -like '*windows-amd64*' } |
        Select-Object -First 1

    if ($localHelm) {
        return $localHelm.FullName
    }

    return $null
}

function Get-CommandSummary {
    param(
        [string]$Name,
        [string]$ExplicitPath
    )

    $resolvedPath = $ExplicitPath
    if (-not $resolvedPath) {
        $command = Get-Command $Name -ErrorAction SilentlyContinue
        if ($command) {
            $resolvedPath = $command.Source
        }
    }

    if (-not $resolvedPath) {
        return @{
            status = 'missing'
            path = ''
            version = ''
        }
    }

    $version = ''
    try {
        if ($Name -eq 'docker') {
            $version = (& $resolvedPath --version 2>$null | Select-Object -First 1)
        } elseif ($Name -eq 'kubectl') {
            $version = (& $resolvedPath version --client --output=yaml 2>$null | Select-String 'gitVersion:' | Select-Object -First 1).ToString().Trim()
        } elseif ($Name -eq 'helm') {
            $version = (& $resolvedPath version --template '{{.Version}}' 2>$null | Select-Object -First 1)
        } else {
            $version = (& $resolvedPath --version 2>$null | Select-Object -First 1)
        }
    } catch {
        $version = ''
    }

    return @{
        status = 'present'
        path = $resolvedPath
        version = $version
    }
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

$helmPath = Get-HelmExecutable
$toolSummaries = [ordered]@{
    git        = Get-CommandSummary -Name 'git'
    docker     = Get-CommandSummary -Name 'docker'
    kubectl    = Get-CommandSummary -Name 'kubectl'
    helm       = Get-CommandSummary -Name 'helm' -ExplicitPath $helmPath
    java       = Get-CommandSummary -Name 'java'
    mvn        = Get-CommandSummary -Name 'mvn'
    node       = Get-CommandSummary -Name 'node'
    npm        = Get-CommandSummary -Name 'npm'
    powershell = Get-CommandSummary -Name 'powershell'
    sh         = Get-CommandSummary -Name 'sh'
}

$dockerDaemonReachable = $false
if ($toolSummaries['docker'].status -eq 'present') {
    try {
        docker version *> $null
        $dockerDaemonReachable = ($LASTEXITCODE -eq 0)
    } catch {
        $dockerDaemonReachable = $false
    }
}

$sourceRootExists = Test-Path 'yas-source'
$serviceCatalogExists = Test-Path 'jenkins\services.env'
$releaseBaselineExists = Test-Path 'jenkins\services.release-baseline.env'
$portableHelmExists = $null -ne $helmPath -and ($helmPath -like '*work\tools*')
$statusEvidenceExists = Test-Path 'work\status-report.generated.md'
$serviceVerificationExists = Test-Path 'work\service-verification.generated.md'
$finalNotesExists = Test-Path 'work\final-report-notes.generated.md'

$content = New-Object System.Collections.Generic.List[string]
$content.Add('# Host Capabilities Report')
$content.Add('')
$content.Add("Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$content.Add('')
$content.Add('## Tool Availability')
foreach ($entry in $toolSummaries.GetEnumerator()) {
    $name = $entry.Key
    $summary = $entry.Value
    if ($summary.status -eq 'present') {
        $line = '- `' + $name + '`: present'
        if ($summary.version) {
            $line += ' (' + $summary.version + ')'
        }
        if ($summary.path) {
            $line += ' at `' + $summary.path + '`'
        }
        $content.Add($line)
    } else {
        $content.Add('- `' + $name + '`: missing')
    }
}
$content.Add('')
$content.Add('## Runtime Reachability')
if ($toolSummaries['docker'].status -eq 'present') {
    if ($dockerDaemonReachable) {
        $content.Add('- Docker daemon: reachable')
    } else {
        $content.Add('- Docker daemon: unreachable from the current execution context')
    }
} else {
    $content.Add('- Docker daemon: not checked because the Docker CLI is missing')
}
$content.Add('')
$content.Add('## Workspace Inputs')
$content.Add('- `yas-source/`: ' + ($(if ($sourceRootExists) { 'present' } else { 'missing' })))
$content.Add('- `jenkins/services.env`: ' + ($(if ($serviceCatalogExists) { 'present' } else { 'missing' })))
$content.Add('- `jenkins/services.release-baseline.env`: ' + ($(if ($releaseBaselineExists) { 'present' } else { 'missing' })))
$content.Add('- Portable Helm under `work/tools/`: ' + ($(if ($portableHelmExists) { 'present' } else { 'missing' })))
$content.Add('')
$content.Add('## Generated Evidence Snapshot')
$content.Add('- `work/status-report.generated.md`: ' + ($(if ($statusEvidenceExists) { 'present' } else { 'missing' })))
$content.Add('- `work/service-verification.generated.md`: ' + ($(if ($serviceVerificationExists) { 'present' } else { 'missing' })))
$content.Add('- `work/final-report-notes.generated.md`: ' + ($(if ($finalNotesExists) { 'present' } else { 'missing' })))
$content.Add('')
$content.Add('## Interpretation')
$content.Add('- This file records what the current host can and cannot do before real Jenkins, registry, and cluster infrastructure are attached.')
$content.Add('- Use it together with `work/status-report.generated.md` to distinguish repo-complete work from environment-complete work.')

[System.IO.File]::WriteAllLines($resolvedOutputPath, $content)
Write-Host "Generated host capabilities report: $OutputFile"

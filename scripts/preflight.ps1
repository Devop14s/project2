param(
    [switch]$AsJson,
    [switch]$SkipCommandChecks
)

function Test-ToolAvailable {
    param(
        [string]$CommandName
    )

    if ($null -ne (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
        return $true
    }

    if ($CommandName -eq 'helm') {
        $localHelm = Get-ChildItem -Path 'work\tools' -Filter 'helm.exe' -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -like '*windows-amd64*' } |
            Select-Object -First 1
        return $null -ne $localHelm
    }

    return $false
}

function Get-CommandStatus {
    param(
        [string]$CommandName
    )

    $exists = Test-ToolAvailable -CommandName $CommandName
    if (-not $exists) {
        return 'missing'
    }

    if ($CommandName -eq 'docker') {
        try {
            docker version *> $null
            if ($LASTEXITCODE -eq 0) {
                return 'ok'
            }
        } catch {
        }

        return 'present but daemon inaccessible'
    }

    return 'ok'
}

$requiredFiles = @(
    'README.md',
    'Jenkinsfile',
    'jenkins\README.md',
    'jenkins\services.env',
    'jenkins\services.release-baseline.env',
    'jenkins\scripts\capture-runtime-evidence.sh',
    'jenkins\scripts\write-commit-metadata.sh',
    'helm\yas\Chart.yaml',
    'helm\yas\values.yaml',
    'docs\status-report.md',
    'argocd\app-dev.yaml',
    'mesh\peer-authentication.yaml',
    'scripts\preflight.ps1',
    'scripts\preflight.sh',
    'scripts\developer-build-dry-run.ps1',
    'scripts\developer-build-dry-run.sh',
    'scripts\catalog.ps1',
    'scripts\catalog.sh',
    'scripts\source-root.ps1',
    'scripts\source-root.sh',
    'scripts\selftest.ps1',
    'scripts\selftest.sh',
    'scripts\validate-services-catalog.ps1',
    'scripts\validate-services-catalog.sh',
    'scripts\validate-chart-values.ps1',
    'scripts\validate-chart-values.sh',
    'scripts\validate-gitops-values.ps1',
    'scripts\validate-gitops-values.sh',
    'scripts\validate-source-alignment.ps1',
    'scripts\validate-source-alignment.sh',
    'scripts\report-status.ps1',
    'scripts\report-status.sh',
    'scripts\resolve-branch-tags.ps1',
    'scripts\resolve-branch-tags.sh',
    'scripts\generate-values.ps1',
    'scripts\generate-values.sh',
    'scripts\generate-gitops-values.ps1',
    'scripts\generate-gitops-values.sh',
    'scripts\generate-chart-values.ps1',
    'scripts\generate-chart-values.sh',
    'scripts\update-manifest-values.ps1',
    'scripts\update-manifest-values.sh'
)

$requiredCommands = @(
    'git',
    'kubectl',
    'helm',
    'docker'
)

$fileResults = foreach ($file in $requiredFiles) {
    [pscustomobject]@{
        type = 'file'
        name = $file
        status = if (Test-Path $file) { 'ok' } else { 'missing' }
    }
}

$commandResults = foreach ($cmd in $requiredCommands) {
    [pscustomobject]@{
        type = 'command'
        name = $cmd
        status = Get-CommandStatus -CommandName $cmd
    }
}

$results = @($fileResults)
if (-not $SkipCommandChecks) {
    $results += $commandResults
}

$missing = $results | Where-Object { $_.status -ne 'ok' }

if ($AsJson) {
    $results | ConvertTo-Json -Depth 3
    if ($missing) {
        exit 1
    }
    exit 0
}

$results | Format-Table -AutoSize

if ($missing) {
    Write-Host ''
    Write-Host 'Missing items detected.' -ForegroundColor Yellow
    exit 1
}

Write-Host ''
Write-Host 'All scaffold preflight checks passed.' -ForegroundColor Green

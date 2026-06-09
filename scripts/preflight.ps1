param(
    [switch]$AsJson,
    [switch]$SkipCommandChecks
)

$requiredFiles = @(
    'README.md',
    'Jenkinsfile',
    'jenkins\README.md',
    'jenkins\services.env',
    'helm\yas\Chart.yaml',
    'helm\yas\values.yaml',
    'docs\status-report.md',
    'argocd\app-dev.yaml',
    'mesh\peer-authentication.yaml',
    'scripts\preflight.ps1',
    'scripts\preflight.sh',
    'scripts\developer-build-dry-run.ps1',
    'scripts\developer-build-dry-run.sh',
    'scripts\selftest.ps1',
    'scripts\selftest.sh',
    'scripts\validate-services-catalog.ps1',
    'scripts\validate-services-catalog.sh',
    'scripts\validate-chart-values.ps1',
    'scripts\validate-chart-values.sh',
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
    $exists = $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
    [pscustomobject]@{
        type = 'command'
        name = $cmd
        status = if ($exists) { 'ok' } else { 'missing' }
    }
}

$results = @($fileResults)
if (-not $SkipCommandChecks) {
    $results += $commandResults
}

if ($AsJson) {
    $results | ConvertTo-Json -Depth 3
    exit 0
}

$results | Format-Table -AutoSize

$missing = $results | Where-Object { $_.status -ne 'ok' }
if ($missing) {
    Write-Host ''
    Write-Host 'Missing items detected.' -ForegroundColor Yellow
    exit 1
}

Write-Host ''
Write-Host 'All scaffold preflight checks passed.' -ForegroundColor Green

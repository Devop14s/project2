param(
    [string]$NotesFile = 'work/final-report-notes.generated.md',
    [string]$BaselineServicesFile = 'jenkins/services.release-baseline.env'
)

foreach ($requiredFile in @($NotesFile, $BaselineServicesFile)) {
    if (-not (Test-Path $requiredFile)) {
        throw "Required file not found: $requiredFile"
    }
}

$notesText = Get-Content $NotesFile -Raw -ErrorAction Stop

foreach ($requiredToken in @(
    '# Final Report Notes',
    'docs/final-report-template.md',
    'work/status-report.generated.md',
    'work/service-verification.generated.md',
    'work/host-capabilities.generated.md',
    'work/image-digests.txt',
    'work/commit-metadata.json',
    'work/runtime-evidence/<namespace>/<release>/',
    'work/cleanup-evidence/<namespace>/<release>/',
    'work/manifest-update-metadata.json',
    'scripts\refresh-evidence.ps1 -SkipCommandChecks',
    'Verified locally only:',
    'Current host capability evidence:',
    'Verified end to end on real infrastructure:'
)) {
    if (-not $notesText.Contains($requiredToken)) {
        throw "Generated final report notes are missing required token $requiredToken."
    }
}

foreach ($line in Get-Content $BaselineServicesFile) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
        continue
    }

    $service = $line.Split('|')[0].Trim()
    $serviceToken = '- `' + $service + '`'
    if (-not $notesText.Contains($serviceToken)) {
        throw "Generated final report notes are missing baseline service $serviceToken."
    }
}

Write-Host 'Generated final report notes are aligned with the current baseline subset and evidence handoff paths.'

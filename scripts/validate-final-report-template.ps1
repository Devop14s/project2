param(
    [string]$TemplateFile = 'docs/final-report-template.md'
)

$templateText = Get-Content $TemplateFile -Raw

foreach ($requiredToken in @(
    'scripts\refresh-evidence.ps1 -SkipCommandChecks',
    'work/final-report-notes.generated.md',
    'work/host-capabilities.generated.md',
    'work/image-digests.txt',
    'work/cleanup-evidence/<namespace>/<release>/',
    'work/commit-metadata.json',
    'work/runtime-evidence/<namespace>/<release>/copied-artifacts.txt',
    'ArgoCD',
    'Service mesh',
    'scaffold-only',
    'which host or Jenkins agent actually ran the flow',
    'which host/tooling constraints still applied while local evidence was collected',
    'verified end to end on real infrastructure'
)) {
    if (-not $templateText.Contains($requiredToken)) {
        throw "docs/final-report-template.md is missing required token $requiredToken."
    }
}

Write-Host 'docs/final-report-template.md is aligned with the current evidence and reporting requirements.'

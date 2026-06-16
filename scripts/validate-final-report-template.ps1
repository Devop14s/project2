param(
    [string]$TemplateFile = 'docs/final-report-template.md'
)

$templateText = Get-Content $TemplateFile -Raw

foreach ($requiredToken in @(
    'work/image-digests.txt',
    'work/cleanup-evidence/<namespace>/<release>/',
    'work/commit-metadata.json',
    'work/runtime-evidence/<namespace>/<release>/copied-artifacts.txt',
    'ArgoCD',
    'Service mesh',
    'scaffold-only',
    'verified end to end on real infrastructure'
)) {
    if (-not $templateText.Contains($requiredToken)) {
        throw "docs/final-report-template.md is missing required token $requiredToken."
    }
}

Write-Host 'docs/final-report-template.md is aligned with the current evidence and reporting requirements.'

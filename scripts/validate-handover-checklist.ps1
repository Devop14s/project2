param(
    [string]$ChecklistFile = 'docs/handover-checklist.md'
)

$checklistText = Get-Content $ChecklistFile -Raw

foreach ($requiredToken in @(
    '`release-baseline`',
    '`full`',
    '`DOCKERHUB_NAMESPACE`',
    '`dockerhub-creds`',
    '`kubeconfig-file`',
    '`yas-ci`',
    '`yas-developer-build`',
    '`yas-developer-cleanup`',
    '`yas-dev-cd`',
    '`yas-staging-release`',
    '`work/runtime-evidence/<namespace>/<release>/`',
    '`work/manifest-update-metadata.json`',
    'scripts\report-status.ps1 -SkipCommandChecks',
    'sampledata',
    'search',
    'Keycloak'
)) {
    if (-not $checklistText.Contains($requiredToken)) {
        throw "docs/handover-checklist.md is missing required token $requiredToken."
    }
}

Write-Host 'docs/handover-checklist.md is aligned with the current registry, Jenkins, cluster, GitOps, and blocker handover scope.'

param(
    [string]$ReadmeFile = 'argocd/README.md'
)

$readmeText = Get-Content $ReadmeFile -Raw

foreach ($requiredToken in @(
    '`app-dev.yaml`',
    '`app-staging.yaml`',
    '`argocd/values/*.yaml`',
    '`validate-argocd-apps`',
    '`main` target revision',
    '`CreateNamespace=true`',
    '`SERVICE_CATALOG=release-baseline`',
    '`work/manifest-update-metadata.json`',
    '`jenkins/services.release-baseline.env`',
    '`jenkins/services.env`'
)) {
    if (-not $readmeText.Contains($requiredToken)) {
        throw "argocd/README.md is missing required token $requiredToken."
    }
}

Write-Host 'argocd/README.md is aligned with the current ArgoCD manifest, overlay, and manifest-update metadata contracts.'

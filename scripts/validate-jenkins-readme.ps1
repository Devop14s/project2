param(
    [string]$ReadmeFile = 'jenkins/README.md'
)

$readmeText = Get-Content $ReadmeFile -Raw

foreach ($requiredToken in @(
    '`yas-ci`',
    '`yas-developer-build`',
    '`yas-developer-cleanup`',
    '`yas-dev-cd`',
    '`yas-staging-release`',
    '`DOCKERHUB_NAMESPACE`',
    '`SERVICE_CATALOG`',
    '`SOURCE_ROOT`',
    '`SOURCE_GIT_ROOT`',
    '`jenkins/services.release-baseline.env`',
    '`jenkins/services.env`',
    '`work/runtime-evidence/<namespace>/<release>/`',
    '`work/manifest-update-metadata.json`',
    '`ALLOW_SHARED_ENVIRONMENT_CLEANUP=true`',
    '`ALLOW_SHARED_NAMESPACE_DELETE=true`'
)) {
    if (-not $readmeText.Contains($requiredToken)) {
        throw "jenkins/README.md is missing required token $requiredToken."
    }
}

Write-Host 'jenkins/README.md is aligned with the current Jenkins job, catalog, and runtime-evidence contracts.'

param(
    [string]$DocsRoot = 'docs'
)

function Assert-ContainsAll {
    param(
        [string]$FilePath,
        [string[]]$Tokens
    )

    $text = Get-Content $FilePath -Raw
    foreach ($token in $Tokens) {
        if (-not $text.Contains($token)) {
            throw "$FilePath is missing required token $token."
        }
    }
}

Assert-ContainsAll -FilePath (Join-Path $DocsRoot 'ci-flow.md') -Tokens @(
    'DOCKERHUB_NAMESPACE',
    'SOURCE_ROOT',
    'SOURCE_GIT_ROOT',
    'work/commit-metadata.json',
    'work/image-digests.txt'
)

Assert-ContainsAll -FilePath (Join-Path $DocsRoot 'deployment-topology.md') -Tokens @(
    '`yas-dev`',
    '`yas-staging`',
    '`yas-user-<developer-id>`',
    '`NodePort`',
    '`storefront-dev.yas.local`',
    '`storefront-staging.yas.local`'
)

Assert-ContainsAll -FilePath (Join-Path $DocsRoot 'dev-environment.md') -Tokens @(
    '`main`',
    '`yas-dev`',
    '`work/commit_sha.txt`',
    '`work/commit_short_sha.txt`',
    '`work/commit-metadata.json`'
)

Assert-ContainsAll -FilePath (Join-Path $DocsRoot 'developer-build.md') -Tokens @(
    '`DEPLOYER_ID`',
    '`SERVICE_CATALOG`',
    '`work/verified-image-list.txt`',
    '`work/branch-tag-metadata.json`',
    '`work/runtime-evidence/<namespace>/<release>/`',
    '`storefront`',
    '`backoffice`'
)

Assert-ContainsAll -FilePath (Join-Path $DocsRoot 'developer-cleanup.md') -Tokens @(
    '`DELETE_NAMESPACE`',
    '`ALLOW_SHARED_ENVIRONMENT_CLEANUP`',
    '`ALLOW_SHARED_NAMESPACE_DELETE`',
    '`work/cleanup-evidence/<namespace>/<release>/`'
)

Assert-ContainsAll -FilePath (Join-Path $DocsRoot 'local-dry-run.md') -Tokens @(
    'scripts\developer-build-dry-run.ps1',
    'scripts/developer-build-dry-run.sh',
    'scripts\selftest.ps1',
    'scripts/selftest.sh',
    'scripts\preflight.ps1 -SkipCommandChecks',
    'scripts/preflight.sh --skip-command-checks',
    'work/final-report-notes.generated.md'
)

Assert-ContainsAll -FilePath (Join-Path $DocsRoot 'local-k8s-bootstrap.md') -Tokens @(
    '`kubectl`',
    '`helm`',
    'Jenkins',
    '`helm template`'
)

Assert-ContainsAll -FilePath (Join-Path $DocsRoot 'staging-release.md') -Tokens @(
    '`yas-staging`',
    '`work/image-digests.txt`',
    '`work/runtime-evidence/yas-staging/yas-staging/`',
    '`work/commit-metadata.json`'
)

Assert-ContainsAll -FilePath (Join-Path $DocsRoot 'argocd-flow.md') -Tokens @(
    '`argocd/app-dev.yaml`',
    '`argocd/app-staging.yaml`',
    '`argocd/values/dev-values.yaml`',
    '`argocd/values/staging-values.yaml`',
    '`jenkins/services.release-baseline.env`',
    '`jenkins/services.env`',
    '`work/manifest-update-metadata.json`'
)

Write-Host 'Operational runbooks and topology docs are aligned with the current pipeline, runtime-evidence, and GitOps contracts.'

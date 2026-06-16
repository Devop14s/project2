param(
    [string]$DockerhubNamespace = 'demo-ns'
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

$tempDir = Join-Path $env:TEMP 'yas-scaffold-selftest'
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$branchTagsFile = Join-Path $tempDir 'branch-tags.env'
$branchTagMetadataFile = Join-Path $tempDir 'branch-tag-metadata.json'
$branchTagMetadataNestedFile = Join-Path $tempDir 'metadata\branch-tag-metadata.json'
$sourceGitBranchTagsFile = Join-Path $tempDir 'source-git-branch-tags.env'
$generatedValuesFile = Join-Path $tempDir 'generated-values.yaml'
$devGeneratedValuesFile = Join-Path $tempDir 'dev-generated-values.yaml'
$gitopsValuesFile = Join-Path $tempDir 'gitops-values.yaml'
$gitopsNamespaceValuesFile = Join-Path $tempDir 'gitops-values-with-namespace.yaml'
$chartValuesFile = Join-Path $tempDir 'chart-values.yaml'
$manifestValuesFile = Join-Path $tempDir 'dev-values.yaml'
$helmRenderFile = Join-Path $tempDir 'helm-render.yaml'
$baselineHelmRenderFile = Join-Path $tempDir 'baseline-helm-render.yaml'
$gitopsDevHelmRenderFile = Join-Path $tempDir 'gitops-dev-helm-render.yaml'
$gitopsStagingHelmRenderFile = Join-Path $tempDir 'gitops-staging-helm-render.yaml'
$sampleDevHelmRenderFile = Join-Path $tempDir 'sample-dev-helm-render.yaml'
$sampleStagingHelmRenderFile = Join-Path $tempDir 'sample-staging-helm-render.yaml'
$sampleDeveloperHelmRenderFile = Join-Path $tempDir 'sample-developer-helm-render.yaml'
$statusReportFile = Join-Path $tempDir 'status-report.generated.md'
$failsafeBlockersFile = Join-Path $tempDir 'failsafe-blockers.txt'
$serviceVerificationMatrixFile = Join-Path $tempDir 'service-verification.generated.md'
$preflightJsonFile = Join-Path $tempDir 'preflight.json'
$helmExecutable = Get-HelmExecutable

try {
    Copy-Item 'argocd\values\dev-values.yaml' $manifestValuesFile -Force

    powershell -ExecutionPolicy Bypass -File scripts\validate-services-catalog.ps1 | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\validate-services-catalog.ps1 `
        -ServicesFile 'jenkins\services.release-baseline.env' `
        -ReferenceServicesFile 'jenkins\services.env' | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\validate-argocd-apps.ps1 | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\validate-chart-values.ps1 | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\validate-image-matrix.ps1 | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\validate-readme.ps1 | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\validate-service-inventory.ps1 | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\validate-troubleshooting.ps1 | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\validate-remaining-work-plan.ps1 | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\validate-gitops-values.ps1 | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\validate-source-alignment.ps1 | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\validate-source-build-runtime-matrix.ps1 | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\validate-status-report.ps1 | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\summarize-failsafe-blockers.ps1 -OutputFile $failsafeBlockersFile | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\generate-service-verification-matrix.ps1 -OutputFile $serviceVerificationMatrixFile | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\resolve-branch-tags.ps1 -OutputFile $branchTagsFile -MetadataFile $branchTagMetadataNestedFile | Out-Null

    $previousProductBranch = [Environment]::GetEnvironmentVariable('PRODUCT_BRANCH')
    [Environment]::SetEnvironmentVariable('PRODUCT_BRANCH', 'HEAD')
    try {
        powershell -ExecutionPolicy Bypass -File scripts\resolve-branch-tags.ps1 -SourceGitRoot 'yas-source' -OutputFile $sourceGitBranchTagsFile -MetadataFile $branchTagMetadataNestedFile | Out-Null
    } finally {
        [Environment]::SetEnvironmentVariable('PRODUCT_BRANCH', $previousProductBranch)
    }

    $previousStorefrontBranch = [Environment]::GetEnvironmentVariable('STOREFRONT_BRANCH')
    [Environment]::SetEnvironmentVariable('STOREFRONT_BRANCH', '')
    try {
        powershell -ExecutionPolicy Bypass -File scripts\resolve-branch-tags.ps1 -OutputFile $branchTagsFile -MetadataFile $branchTagMetadataNestedFile | Out-Null
    } finally {
        [Environment]::SetEnvironmentVariable('STOREFRONT_BRANCH', $previousStorefrontBranch)
    }

    powershell -ExecutionPolicy Bypass -File scripts\generate-values.ps1 `
        -TagsFile $branchTagsFile `
        -OutputFile $generatedValuesFile `
        -DockerhubNamespace $DockerhubNamespace | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\generate-values.ps1 `
        -OutputFile $devGeneratedValuesFile `
        -EnvironmentName dev `
        -DockerhubNamespace $DockerhubNamespace | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\generate-gitops-values.ps1 `
        -TagsFile $branchTagsFile `
        -OutputFile $gitopsValuesFile `
        -EnvironmentName dev | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\generate-gitops-values.ps1 `
        -TagsFile $branchTagsFile `
        -OutputFile $gitopsNamespaceValuesFile `
        -EnvironmentName dev `
        -DockerhubNamespace $DockerhubNamespace | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\generate-chart-values.ps1 `
        -OutputFile $chartValuesFile | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\update-manifest-values.ps1 `
        -ValuesFile $manifestValuesFile `
        -Tag test-tag | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\preflight.ps1 `
        -AsJson `
        -SkipCommandChecks > $preflightJsonFile
    if ($LASTEXITCODE -ne 0) {
        throw 'preflight.ps1 -AsJson -SkipCommandChecks should succeed in the repo root.'
    }
    powershell -ExecutionPolicy Bypass -File scripts\report-status.ps1 `
        -OutputFile $statusReportFile `
        -SkipCommandChecks | Out-Null
    if ($helmExecutable) {
        & $helmExecutable lint 'helm\yas' | Out-Null
        & $helmExecutable template yas 'helm\yas' | Out-File -FilePath $helmRenderFile -Encoding utf8
    }

    $branchTags = Get-Content $branchTagsFile -Raw
    if (-not (Test-Path $branchTagMetadataNestedFile)) {
        throw 'resolve-branch-tags.ps1 did not create the requested metadata file path.'
    }

    $branchTagMetadata = Get-Content $branchTagMetadataNestedFile -Raw
    $generatedValues = Get-Content $generatedValuesFile -Raw
    $devGeneratedValues = Get-Content $devGeneratedValuesFile -Raw
    $gitopsValues = Get-Content $gitopsValuesFile -Raw
    $gitopsNamespaceValues = Get-Content $gitopsNamespaceValuesFile -Raw
    $chartValues = Get-Content $chartValuesFile -Raw
    $manifestValues = Get-Content $manifestValuesFile -Raw
    $statusReport = Get-Content $statusReportFile -Raw
    $failsafeBlockers = Get-Content $failsafeBlockersFile -Raw
    $serviceVerificationMatrix = Get-Content $serviceVerificationMatrixFile -Raw
    $preflightJson = Get-Content $preflightJsonFile -Raw
    $helmRender = if (Test-Path $helmRenderFile) { Get-Content $helmRenderFile -Raw } else { '' }

    if ($branchTags -notmatch 'TAX_TAG=main') {
        throw 'Branch tag resolution failed for tax service.'
    }

    if ($branchTags -notmatch 'STOREFRONT_TAG=main') {
        throw 'Branch tag resolution should treat empty storefront branch overrides as main.'
    }

    if ($branchTagMetadata -notmatch '"service":\s*"storefront"') {
        throw 'Branch-tag metadata is missing the storefront entry.'
    }

    if ($failsafeBlockers -notmatch '(?m)^media\|keycloak\|') {
        throw 'summarize-failsafe-blockers.ps1 should detect the media Keycloak blocker.'
    }

    if ($failsafeBlockers -notmatch '(?m)^rating\|keycloak\|') {
        throw 'summarize-failsafe-blockers.ps1 should detect the rating Keycloak blocker.'
    }

    if ($serviceVerificationMatrix -notmatch '\| product \| backend \| yes \(`jar`\) \| (yes|no) \| none \| full build verified( \+ image verified)? \|') {
        throw 'generate-service-verification-matrix.ps1 should report product as fully build-verified.'
    }

    if ($serviceVerificationMatrix -notmatch '\| search \| backend \| yes \(`jar`\) \| (yes|no) \| elasticsearch: ProductCdcConsumerTest \| (package\+image verified|build artifact verified), full test path blocked \|') {
        throw 'generate-service-verification-matrix.ps1 should report the search Elasticsearch blocker.'
    }

    $imageMatrix = Get-Content 'docs\image-matrix.md' -Raw
    if ($imageMatrix -notmatch 'work/service-verification.generated.md') {
        throw 'docs/image-matrix.md should reference the generated service verification matrix.'
    }

    $readme = Get-Content 'README.md' -Raw
    if ($readme -notmatch 'work/service-verification.generated.md') {
        throw 'README.md should reference the generated service verification matrix.'
    }

    $serviceInventory = Get-Content 'docs\service-inventory.md' -Raw
    if ($serviceInventory -notmatch 'work/service-verification.generated.md') {
        throw 'docs/service-inventory.md should reference the generated service verification matrix.'
    }

    $troubleshooting = Get-Content 'docs\troubleshooting.md' -Raw
    if ($troubleshooting -notmatch 'work/service-verification.generated.md') {
        throw 'docs/troubleshooting.md should reference the generated service verification matrix.'
    }

    $remainingWorkPlan = Get-Content 'docs\remaining-work-plan.md' -Raw
    if ($remainingWorkPlan -notmatch 'work/service-verification.generated.md') {
        throw 'docs/remaining-work-plan.md should reference the generated service verification matrix.'
    }

    if ($branchTagMetadata -notmatch '"branch":\s*"main"') {
        throw 'Branch-tag metadata is missing the resolved branch values.'
    }

    if ($branchTagMetadata -notmatch '"tag":\s*"main"') {
        throw 'Branch-tag metadata is missing the resolved tag values.'
    }

    $resolveBranchTagsShellScript = Get-Content 'scripts\resolve-branch-tags.sh' -Raw
    if ($resolveBranchTagsShellScript -match 'done < <\(') {
        throw 'resolve-branch-tags.sh should remain POSIX-safe and must not use process substitution.'
    }

    if ($resolveBranchTagsShellScript -notmatch 'Services file not found: %s') {
        throw 'resolve-branch-tags.sh should fail fast when the selected services catalog is missing.'
    }

    if ($resolveBranchTagsShellScript -notmatch 'Source git root not found: %s') {
        throw 'resolve-branch-tags.sh should fail fast when SOURCE_GIT_ROOT points to a missing directory.'
    }

    if ($resolveBranchTagsShellScript -notmatch 'Source git root is not a git repository: %s') {
        throw 'resolve-branch-tags.sh should fail fast when SOURCE_GIT_ROOT is not a Git repository.'
    }

    $expectedSourceHead = (& git -C 'yas-source' rev-parse HEAD).Trim()
    $sourceGitBranchTags = Get-Content $sourceGitBranchTagsFile -Raw
    if ($sourceGitBranchTags -notmatch ("PRODUCT_TAG=" + [regex]::Escape($expectedSourceHead))) {
        throw 'Branch tag resolution did not use the expected source Git root.'
    }

    $missingServicesBranchTagsFile = Join-Path $tempDir 'missing-services-branch-tags.env'
    $missingServicesBranchMetadataFile = Join-Path $tempDir 'missing-services-branch-tag-metadata.json'
    powershell -ExecutionPolicy Bypass -File scripts\resolve-branch-tags.ps1 `
        -ServicesFile (Join-Path $tempDir 'missing-services.env') `
        -OutputFile $missingServicesBranchTagsFile `
        -MetadataFile $missingServicesBranchMetadataFile *> $null
    if ($LASTEXITCODE -eq 0) {
        throw 'resolve-branch-tags.ps1 should fail when the selected services catalog does not exist.'
    }

    $nonGitSourceRoot = Join-Path $tempDir 'non-git-source'
    New-Item -ItemType Directory -Path $nonGitSourceRoot -Force | Out-Null
    $invalidSourceRootBranchTagsFile = Join-Path $tempDir 'invalid-source-root-branch-tags.env'
    $invalidSourceRootMetadataFile = Join-Path $tempDir 'invalid-source-root-branch-tag-metadata.json'
    powershell -ExecutionPolicy Bypass -File scripts\resolve-branch-tags.ps1 `
        -SourceGitRoot $nonGitSourceRoot `
        -OutputFile $invalidSourceRootBranchTagsFile `
        -MetadataFile $invalidSourceRootMetadataFile *> $null
    if ($LASTEXITCODE -eq 0) {
        throw 'resolve-branch-tags.ps1 should fail when SOURCE_GIT_ROOT is not a Git repository.'
    }

    if ($generatedValues -notmatch 'repository: demo-ns/yas-storefront-bff') {
        throw 'Generated values are missing storefront-bff repository.'
    }

    $missingTagsGeneratedValuesFile = Join-Path $tempDir 'missing-tags-generated-values.yaml'
    powershell -ExecutionPolicy Bypass -File scripts\generate-values.ps1 `
        -TagsFile (Join-Path $tempDir 'missing-tags.env') `
        -OutputFile $missingTagsGeneratedValuesFile `
        -DockerhubNamespace $DockerhubNamespace *> $null
    if ($LASTEXITCODE -eq 0) {
        throw 'generate-values.ps1 should fail when an explicit TagsFile path is provided but missing.'
    }

    $missingTagsGitopsValuesFile = Join-Path $tempDir 'missing-tags-gitops-values.yaml'
    powershell -ExecutionPolicy Bypass -File scripts\generate-gitops-values.ps1 `
        -TagsFile (Join-Path $tempDir 'missing-gitops-tags.env') `
        -OutputFile $missingTagsGitopsValuesFile `
        -EnvironmentName dev *> $null
    if ($LASTEXITCODE -eq 0) {
        throw 'generate-gitops-values.ps1 should fail when an explicit TagsFile path is provided but missing.'
    }

    if ($generatedValues -notmatch 'workloadType: ui') {
        throw 'Generated values are missing ui workload classification.'
    }

    if ($generatedValues -notmatch 'host: storefront-dev1.yas.local') {
        throw 'Generated values are missing the storefront ingress host.'
    }

    if ($generatedValues -notmatch 'host: backoffice-dev1.yas.local') {
        throw 'Generated values are missing the backoffice ingress host.'
    }

    $jenkinsfile = Get-Content 'Jenkinsfile' -Raw
    if ($jenkinsfile -notmatch "'developer_cleanup'") {
        throw 'Jenkinsfile is missing the developer_cleanup dispatch target.'
    }

    $trackedShellFiles = & git ls-files --stage -- 'jenkins/scripts/*.sh' 'scripts/*.sh'
    if (-not $trackedShellFiles) {
        throw 'Git did not report any tracked shell scripts for execute-bit validation.'
    }
    foreach ($trackedShellFile in $trackedShellFiles) {
        if ($trackedShellFile -notmatch '^100755\s') {
            throw "Tracked shell script is missing the executable git mode: $trackedShellFile"
        }
    }

    if ($jenkinsfile -notmatch 'pipelineRequiresDockerhubNamespace') {
        throw 'Jenkinsfile no longer guards DOCKERHUB_NAMESPACE by pipeline target.'
    }

    if ($jenkinsfile -notmatch "name: 'RELEASE_VERSION'") {
        throw 'Jenkinsfile is missing the shared RELEASE_VERSION parameter.'
    }

    if ($jenkinsfile -notmatch "name: 'DEPLOYER_ID'") {
        throw 'Jenkinsfile is missing the shared DEPLOYER_ID parameter.'
    }

    if ($jenkinsfile -notmatch "name: 'DELETE_NAMESPACE'") {
        throw 'Jenkinsfile is missing the shared DELETE_NAMESPACE cleanup parameter.'
    }

    if ($jenkinsfile -notmatch "name: 'ALLOW_SHARED_ENVIRONMENT_CLEANUP'") {
        throw 'Jenkinsfile is missing the shared ALLOW_SHARED_ENVIRONMENT_CLEANUP cleanup parameter.'
    }

    if ($jenkinsfile -notmatch "name: 'ALLOW_SHARED_NAMESPACE_DELETE'") {
        throw 'Jenkinsfile is missing the shared ALLOW_SHARED_NAMESPACE_DELETE cleanup parameter.'
    }

    if ($jenkinsfile -notmatch "name: 'STOREFRONT_BRANCH'") {
        throw 'Jenkinsfile is missing the shared branch-override parameters for dispatch mode.'
    }

    if ($jenkinsfile -notmatch "PIPELINE_DISPATCH_MODE = 'true'") {
        throw 'Jenkinsfile no longer marks dispatched pipeline execution.'
    }

    if ($jenkinsfile -notmatch 'env\.RELEASE_VERSION = stagingTarget') {
        throw 'Jenkinsfile no longer sanitizes RELEASE_VERSION by dispatched pipeline target.'
    }

    if ($jenkinsfile -notmatch 'env\.DOMAIN_NAME = developerBuildTarget') {
        throw 'Jenkinsfile no longer scopes DOMAIN_NAME to developer-build dispatches.'
    }

    if ($jenkinsfile -notmatch 'env\."\$\{branchParam\}" = developerBuildTarget') {
        throw 'Jenkinsfile no longer scopes branch overrides to developer-build dispatches.'
    }

    $ciPipeline = Get-Content 'jenkins\pipelines\ci.groovy' -Raw
    if ($ciPipeline -notmatch "if \(env\.PIPELINE_DISPATCH_MODE != 'true'\)") {
        throw 'ci.groovy no longer skips properties rewrites in dispatch mode.'
    }

    if ($ciPipeline -notmatch "name: 'DOCKERHUB_NAMESPACE'") {
        throw 'ci.groovy is missing the direct-load DOCKERHUB_NAMESPACE parameter.'
    }

    if ($ciPipeline -notmatch 'DOCKERHUB_NAMESPACE must be provided as a parameter or Jenkins job environment value\.') {
        throw 'ci.groovy no longer validates DOCKERHUB_NAMESPACE for direct-load execution.'
    }

    $developerBuildPipeline = Get-Content 'jenkins\pipelines\developer_build.groovy' -Raw
    if ($developerBuildPipeline -notmatch "if \(env\.PIPELINE_DISPATCH_MODE != 'true'\)") {
        throw 'developer_build.groovy no longer skips properties rewrites in dispatch mode.'
    }

    if ($developerBuildPipeline -notmatch "stage\('Docker Login'\)") {
        throw 'developer_build.groovy is missing the Docker login stage.'
    }

    if ($developerBuildPipeline -notmatch "stage\('Verify Image Tags'\)") {
        throw 'developer_build.groovy is missing the image verification stage.'
    }

    if ($developerBuildPipeline -notmatch "name: 'DOCKERHUB_NAMESPACE'") {
        throw 'developer_build.groovy is missing the direct-load DOCKERHUB_NAMESPACE parameter.'
    }

    $developerBuildDryRunScript = Get-Content 'scripts\developer-build-dry-run.ps1' -Raw
    if ($developerBuildDryRunScript -notmatch '\[string\]\$PaymentBranch = ''main''') {
        throw 'developer-build-dry-run.ps1 no longer exposes the full branch-override surface.'
    }

    if ($developerBuildDryRunScript -notmatch 'branch-tag-metadata\.json') {
        throw 'developer-build-dry-run.ps1 no longer emits branch-tag metadata alongside branch-tags.env.'
    }

    $validateArgocdAppsScript = Get-Content 'scripts\validate-argocd-apps.ps1' -Raw
    if ($validateArgocdAppsScript -notmatch 'helm/yas') {
        throw 'validate-argocd-apps.ps1 no longer verifies the expected Helm chart path.'
    }

    if ($validateArgocdAppsScript -notmatch 'staging-values\.yaml') {
        throw 'validate-argocd-apps.ps1 no longer verifies the staging values file path.'
    }

    if ($validateArgocdAppsScript -notmatch 'https://github\.com/Devop14s/project2\.git') {
        throw 'validate-argocd-apps.ps1 no longer verifies the expected Git repository URL.'
    }

    if ($validateArgocdAppsScript -notmatch 'CreateNamespace=true') {
        throw 'validate-argocd-apps.ps1 no longer verifies the required CreateNamespace sync option.'
    }

    if ($validateArgocdAppsScript -notmatch 'selfHeal:\\s\+true') {
        throw 'validate-argocd-apps.ps1 no longer verifies the dev automated self-heal policy.'
    }

    if ($validateArgocdAppsScript -notmatch 'staging manifest should remain manual-sync') {
        throw 'validate-argocd-apps.ps1 no longer protects the staging manual-sync contract.'
    }

    $validateArgocdAppsShellScript = Get-Content 'scripts\validate-argocd-apps.sh' -Raw
    if ($validateArgocdAppsShellScript -match '\$\{expected_repo_url//') {
        throw 'validate-argocd-apps.sh should remain POSIX-safe and must not use bash-only replacement expansion.'
    }

    if ($validateArgocdAppsShellScript -notmatch 'assert_scalar_value') {
        throw 'validate-argocd-apps.sh is missing the POSIX-safe scalar-value assertion helper.'
    }

    if ($validateArgocdAppsShellScript -notmatch 'assert_list_item') {
        throw 'validate-argocd-apps.sh is missing the POSIX-safe list-item assertion helper.'
    }

    $validateServicesCatalogShellScript = Get-Content 'scripts\validate-services-catalog.sh' -Raw
    if ($validateServicesCatalogShellScript -match 'set -- \$line') {
        throw 'validate-services-catalog.sh should preserve empty catalog columns and must not parse lines with set -- $line.'
    }

    if ($validateServicesCatalogShellScript -match 'set -- \$reference_line') {
        throw 'validate-services-catalog.sh should preserve empty reference-catalog columns and must not parse lines with set -- $reference_line.'
    }

    $generateValuesShellScript = Get-Content 'scripts\generate-values.sh' -Raw
    if ($generateValuesShellScript -match 'set -- \$selected_entry') {
        throw 'generate-values.sh should preserve empty nodePort columns and must not parse selected entries with set -- $selected_entry.'
    }

    if ($generateValuesShellScript -notmatch 'Services file not found: %s') {
        throw 'generate-values.sh should fail fast when the selected services file is missing.'
    }

    if ($generateValuesShellScript -notmatch 'Tags file not found: %s') {
        throw 'generate-values.sh should fail fast when an explicit TAGS_FILE path is provided but missing.'
    }

    $generateGitopsValuesShellScript = Get-Content 'scripts\generate-gitops-values.sh' -Raw
    if ($generateGitopsValuesShellScript -notmatch 'Tags file not found: %s') {
        throw 'generate-gitops-values.sh should fail fast when an explicit TAGS_FILE path is provided but missing.'
    }

    $developerCleanupPipeline = Get-Content 'jenkins\pipelines\developer_cleanup.groovy' -Raw
    if ($developerCleanupPipeline -notmatch "if \(env\.PIPELINE_DISPATCH_MODE != 'true'\)") {
        throw 'developer_cleanup.groovy no longer skips properties rewrites in dispatch mode.'
    }

    if ($developerCleanupPipeline -notmatch "name: 'DELETE_NAMESPACE'") {
        throw 'developer_cleanup.groovy is missing the direct-load DELETE_NAMESPACE parameter.'
    }

    if ($developerCleanupPipeline -notmatch "name: 'ALLOW_SHARED_ENVIRONMENT_CLEANUP'") {
        throw 'developer_cleanup.groovy is missing the direct-load ALLOW_SHARED_ENVIRONMENT_CLEANUP parameter.'
    }

    if ($developerCleanupPipeline -notmatch "name: 'ALLOW_SHARED_NAMESPACE_DELETE'") {
        throw 'developer_cleanup.groovy is missing the direct-load ALLOW_SHARED_NAMESPACE_DELETE parameter.'
    }

    $devCdPipeline = Get-Content 'jenkins\pipelines\dev_cd.groovy' -Raw
    if ($devCdPipeline -notmatch "if \(env\.PIPELINE_DISPATCH_MODE != 'true'\)") {
        throw 'dev_cd.groovy no longer skips properties rewrites in dispatch mode.'
    }

    if ($devCdPipeline -notmatch "name: 'DOCKERHUB_NAMESPACE'") {
        throw 'dev_cd.groovy is missing the direct-load DOCKERHUB_NAMESPACE parameter.'
    }

    if ($devCdPipeline -notmatch "stage\('Resolve Commit Metadata'\)") {
        throw 'dev_cd.groovy is missing the commit-metadata stage for main-tag traceability.'
    }

    if ($devCdPipeline -notmatch 'jenkins/scripts/write-commit-metadata\.sh') {
        throw 'dev_cd.groovy no longer records commit metadata before promoting the main tag.'
    }

    $devGitopsPipeline = Get-Content 'jenkins\pipelines\dev_gitops.groovy' -Raw
    if ($devGitopsPipeline -notmatch "if \(env\.PIPELINE_DISPATCH_MODE != 'true'\)") {
        throw 'dev_gitops.groovy no longer skips properties rewrites in dispatch mode.'
    }

    if ($devGitopsPipeline -notmatch "name: 'DOCKERHUB_NAMESPACE'") {
        throw 'dev_gitops.groovy is missing the direct-load DOCKERHUB_NAMESPACE parameter.'
    }

    if ($devGitopsPipeline -notmatch "stage\('Resolve Commit Metadata'\)") {
        throw 'dev_gitops.groovy is missing the commit-metadata stage for main-tag traceability.'
    }

    if ($devGitopsPipeline -notmatch 'jenkins/scripts/write-commit-metadata\.sh') {
        throw 'dev_gitops.groovy no longer records commit metadata before updating dev GitOps values.'
    }

    $stagingGitopsPipeline = Get-Content 'jenkins\pipelines\staging_gitops.groovy' -Raw
    if ($stagingGitopsPipeline -notmatch "if \(env\.PIPELINE_DISPATCH_MODE != 'true'\)") {
        throw 'staging_gitops.groovy no longer skips properties rewrites in dispatch mode.'
    }

    if ($stagingGitopsPipeline -notmatch "name: 'DOCKERHUB_NAMESPACE'") {
        throw 'staging_gitops.groovy is missing the direct-load DOCKERHUB_NAMESPACE parameter.'
    }

    if ($stagingGitopsPipeline -notmatch "stage\('Resolve Commit Metadata'\)") {
        throw 'staging_gitops.groovy is missing the commit-metadata stage for release traceability.'
    }

    if ($stagingGitopsPipeline -notmatch 'jenkins/scripts/write-commit-metadata\.sh') {
        throw 'staging_gitops.groovy no longer records commit metadata before updating staging GitOps values.'
    }

    $stagingReleasePipeline = Get-Content 'jenkins\pipelines\staging_release.groovy' -Raw
    if ($stagingReleasePipeline -notmatch "if \(env\.PIPELINE_DISPATCH_MODE != 'true'\)") {
        throw 'staging_release.groovy no longer skips properties rewrites in dispatch mode.'
    }

    if ($stagingReleasePipeline -notmatch "name: 'DOCKERHUB_NAMESPACE'") {
        throw 'staging_release.groovy is missing the direct-load DOCKERHUB_NAMESPACE parameter.'
    }

    if ($stagingReleasePipeline -notmatch "stage\('Resolve Commit Metadata'\)") {
        throw 'staging_release.groovy is missing the commit-metadata stage for release traceability.'
    }

    if ($stagingReleasePipeline -notmatch 'jenkins/scripts/write-commit-metadata\.sh') {
        throw 'staging_release.groovy no longer records commit metadata before promoting a release.'
    }

    $jenkinsCommonScript = Get-Content 'jenkins\scripts\common.sh' -Raw
    if ($jenkinsCommonScript -notmatch '\[\[ -f "\$SERVICES_FILE" \]\] \|\| fail "Services file not found: \$\{SERVICES_FILE\}"') {
        throw 'jenkins/scripts/common.sh should fail fast when SERVICES_FILE does not exist before bash helpers iterate services.'
    }

    $writeCommitMetadataScript = Get-Content 'jenkins\scripts\write-commit-metadata.sh' -Raw
    if ($writeCommitMetadataScript -notmatch '"commit_sha": "\$\{commit_sha\}"') {
        throw 'write-commit-metadata.sh is missing the exact commit SHA in commit-metadata.json.'
    }

    if ($writeCommitMetadataScript -notmatch '"commit_short_sha": "\$\{commit_short_sha\}"') {
        throw 'write-commit-metadata.sh is missing the short commit SHA in commit-metadata.json.'
    }

    if ($writeCommitMetadataScript -notmatch 'COMMIT_SHA_FILE="\$\{COMMIT_SHA_FILE:-work/commit_sha\.txt\}"') {
        throw 'write-commit-metadata.sh should allow COMMIT_SHA_FILE to be overridden.'
    }

    if ($writeCommitMetadataScript -notmatch 'COMMIT_SHORT_SHA_FILE="\$\{COMMIT_SHORT_SHA_FILE:-work/commit_short_sha\.txt\}"') {
        throw 'write-commit-metadata.sh should allow COMMIT_SHORT_SHA_FILE to be overridden.'
    }

    if ($writeCommitMetadataScript -notmatch 'COMMIT_METADATA_FILE="\$\{COMMIT_METADATA_FILE:-work/commit-metadata\.json\}"') {
        throw 'write-commit-metadata.sh should allow COMMIT_METADATA_FILE to be overridden.'
    }

    if ($writeCommitMetadataScript -notmatch 'mkdir -p "\$\(dirname "\$COMMIT_METADATA_FILE"\)"') {
        throw 'write-commit-metadata.sh should create the metadata directory when COMMIT_METADATA_FILE is overridden.'
    }

    if ($writeCommitMetadataScript -notmatch '"generated_at":') {
        throw 'write-commit-metadata.sh is missing the metadata generation timestamp.'
    }

    $pushImagesScript = Get-Content 'jenkins\scripts\push-images.sh' -Raw
    $buildImagesScript = Get-Content 'jenkins\scripts\build-images.sh' -Raw
    if ($buildImagesScript -notmatch 'trap ''write_build_metadata \$\?'' EXIT') {
        throw 'build-images.sh is missing the failure-safe build metadata trap.'
    }

    if ($buildImagesScript -notmatch 'done < <\(iter_services\)') {
        throw 'build-images.sh should iterate services without a subshell so failure metadata preserves the last attempted service.'
    }

    if ($buildImagesScript -notmatch '"completed": \$\{build_completed\}') {
        throw 'build-images.sh is missing the build completion marker in metadata.'
    }

    if ($buildImagesScript -notmatch '"last_image": "\$\{last_image\}"') {
        throw 'build-images.sh is missing the last attempted image marker in metadata.'
    }

    if ($buildImagesScript -notmatch 'BUILT_IMAGE_LIST_FILE="\$\{BUILT_IMAGE_LIST_FILE:-work/built-image-list\.txt\}"') {
        throw 'build-images.sh should allow BUILT_IMAGE_LIST_FILE to be overridden.'
    }

    if ($buildImagesScript -notmatch 'BUILD_METADATA_FILE="\$\{BUILD_METADATA_FILE:-work/build-metadata\.json\}"') {
        throw 'build-images.sh should allow BUILD_METADATA_FILE to be overridden.'
    }

    if ($buildImagesScript -notmatch 'mkdir -p "\$\(dirname "\$BUILT_IMAGE_LIST_FILE"\)"') {
        throw 'build-images.sh should create the built-image-list directory when BUILT_IMAGE_LIST_FILE is overridden.'
    }

    if ($buildImagesScript -notmatch 'mkdir -p "\$\(dirname "\$BUILD_METADATA_FILE"\)"') {
        throw 'build-images.sh should create the metadata directory when BUILD_METADATA_FILE is overridden.'
    }

    if ($pushImagesScript -notmatch 'IMAGE_DIGESTS_FILE="\$\{IMAGE_DIGESTS_FILE:-work/image-digests\.txt\}"') {
        throw 'push-images.sh should allow IMAGE_DIGESTS_FILE to be overridden.'
    }

    if ($pushImagesScript -notmatch 'IMAGE_LIST_FILE="\$\{IMAGE_LIST_FILE:-work/image-list\.txt\}"') {
        throw 'push-images.sh should allow IMAGE_LIST_FILE to be overridden.'
    }

    if ($pushImagesScript -notmatch 'METADATA_FILE="\$\{METADATA_FILE:-work/image-metadata\.json\}"') {
        throw 'push-images.sh should allow METADATA_FILE to be overridden.'
    }

    if ($pushImagesScript -notmatch 'mkdir -p "\$\(dirname "\$IMAGE_DIGESTS_FILE"\)"') {
        throw 'push-images.sh should create the digest directory when IMAGE_DIGESTS_FILE is overridden.'
    }

    if ($pushImagesScript -notmatch 'mkdir -p "\$\(dirname "\$METADATA_FILE"\)"') {
        throw 'push-images.sh should create the metadata directory when METADATA_FILE is overridden.'
    }

    if ($pushImagesScript -notmatch 'record_repo_digest') {
        throw 'push-images.sh no longer records repo digests after push.'
    }

    if ($pushImagesScript -notmatch 'trap ''write_push_metadata \$\?'' EXIT') {
        throw 'push-images.sh is missing the failure-safe push metadata trap.'
    }

    if ($pushImagesScript -notmatch 'done < <\(iter_services\)') {
        throw 'push-images.sh should iterate services without a subshell so failure metadata preserves the last attempted service.'
    }

    if ($pushImagesScript -notmatch '"completed": \$\{push_completed\}') {
        throw 'push-images.sh is missing the push completion marker in metadata.'
    }

    if ($pushImagesScript -notmatch '"last_image": "\$\{last_image\}"') {
        throw 'push-images.sh is missing the last attempted image marker in metadata.'
    }

    $verifyImageTagsScript = Get-Content 'jenkins\scripts\verify-image-tags.sh' -Raw
    if ($verifyImageTagsScript -notmatch 'source "\$TAGS_FILE"') {
        throw 'verify-image-tags.sh no longer loads the resolved branch tags file.'
    }

    if ($verifyImageTagsScript -notmatch 'VERIFY_IMAGE_TAGS_DRY_RUN') {
        throw 'verify-image-tags.sh is missing the dry-run path for local verification.'
    }

    if ($verifyImageTagsScript -notmatch 'docker manifest inspect') {
        throw 'verify-image-tags.sh no longer checks remote image availability.'
    }

    if ($verifyImageTagsScript -notmatch 'VERIFIED_IMAGE_LIST_FILE="\$\{VERIFIED_IMAGE_LIST_FILE:-work/verified-image-list.txt\}"') {
        throw 'verify-image-tags.sh is missing the verified image list artifact.'
    }

    if ($verifyImageTagsScript -notmatch 'mkdir -p "\$\(dirname "\$VERIFIED_IMAGE_LIST_FILE"\)"') {
        throw 'verify-image-tags.sh should create the verified-image-list directory when VERIFIED_IMAGE_LIST_FILE is overridden.'
    }

    if ($verifyImageTagsScript -notmatch 'mkdir -p "\$\(dirname "\$VERIFY_METADATA_FILE"\)"') {
        throw 'verify-image-tags.sh should create the metadata directory when VERIFY_METADATA_FILE is overridden.'
    }

    if ($verifyImageTagsScript -notmatch 'Tags file not found: \$\{TAGS_FILE\}') {
        throw 'verify-image-tags.sh should fail fast when an explicit TAGS_FILE path is provided but missing.'
    }

    if ($verifyImageTagsScript -notmatch 'trap ''write_verify_metadata \$\?'' EXIT') {
        throw 'verify-image-tags.sh is missing the failure-safe verify metadata trap.'
    }

    if ($verifyImageTagsScript -notmatch 'done < <\(iter_services\)') {
        throw 'verify-image-tags.sh should iterate services without a subshell so failure metadata preserves the last attempted service.'
    }

    if ($verifyImageTagsScript -notmatch '"completed": \$\{verify_completed\}') {
        throw 'verify-image-tags.sh is missing the verify completion marker in metadata.'
    }

    if ($verifyImageTagsScript -notmatch '"last_image": "\$\{last_image\}"') {
        throw 'verify-image-tags.sh is missing the last attempted image marker in metadata.'
    }

    $captureRuntimeEvidenceScript = Get-Content 'jenkins\scripts\capture-runtime-evidence.sh' -Raw
    if ($captureRuntimeEvidenceScript -notmatch 'copied-artifacts\.txt') {
        throw 'capture-runtime-evidence.sh is missing the copied-artifacts evidence index.'
    }

    if ($captureRuntimeEvidenceScript -notmatch 'branch_tag_metadata_file="\$\{BRANCH_TAG_METADATA_FILE:-work/branch-tag-metadata\.json\}"') {
        throw 'capture-runtime-evidence.sh should resolve branch-tag metadata from the overrideable path contract before snapshotting it.'
    }

    $reportStatusShellScript = Get-Content 'scripts\report-status.sh' -Raw
    if ($reportStatusShellScript -notmatch 'branch_tag_metadata_file="\$\{BRANCH_TAG_METADATA_FILE:-work/branch-tag-metadata\.json\}"') {
        throw 'report-status.sh no longer treats branch-tag metadata as part of the override-aware runtime evidence provenance contract.'
    }

    $expectedSourceRootReportLine = 'printf ''%s%s%s\n'' ''- Service catalog paths and Dockerfiles were verified against the configured source root `'' "$source_root" ''`.'''
    if (-not $reportStatusShellScript.Contains($expectedSourceRootReportLine)) {
        throw 'report-status.sh should render the source-root markdown line without relying on escaped backticks inside a double-quoted shell string.'
    }

    if ($captureRuntimeEvidenceScript -notmatch 'image_digests_file="\$\{IMAGE_DIGESTS_FILE:-work/image-digests\.txt\}"') {
        throw 'capture-runtime-evidence.sh no longer snapshots pushed image digests from the expected override-aware path.'
    }

    if ($captureRuntimeEvidenceScript -notmatch 'commit_metadata_file="\$\{COMMIT_METADATA_FILE:-work/commit-metadata\.json\}"') {
        throw 'capture-runtime-evidence.sh no longer snapshots commit metadata from the expected override-aware path.'
    }

    if ($captureRuntimeEvidenceScript -notmatch 'manifest_metadata_file="\$\{MANIFEST_METADATA_FILE:-work/manifest-update-metadata\.json\}"') {
        throw 'capture-runtime-evidence.sh should resolve manifest metadata from the overrideable path contract before snapshotting it.'
    }

    if ($captureRuntimeEvidenceScript -notmatch 'copy_optional_artifact "\$manifest_metadata_file" "manifest-update-metadata\.json"') {
        throw 'capture-runtime-evidence.sh should snapshot manifest metadata into the per-run evidence directory.'
    }

    if ($captureRuntimeEvidenceScript -notmatch 'CAPTURE_RUNTIME_EXIT_CODE') {
        throw 'capture-runtime-evidence.sh is missing the captured exit-code context.'
    }

    if ($captureRuntimeEvidenceScript -notmatch 'write_namespace_missing_note') {
        throw 'capture-runtime-evidence.sh no longer handles missing namespaces for failure diagnostics.'
    }

    $deployHelmScript = Get-Content 'jenkins\scripts\deploy-helm.sh' -Raw
    if ($deployHelmScript -notmatch 'capture_runtime_evidence_on_exit') {
        throw 'deploy-helm.sh is missing the failure-safe runtime evidence trap.'
    }

    if ($deployHelmScript -notmatch 'done < <\(iter_services\)') {
        throw 'deploy-helm.sh should iterate services without a subshell to avoid losing future loop state.'
    }

    if ($deployHelmScript -notmatch 'CAPTURE_RUNTIME_REASON="deploy-helm"') {
        throw 'deploy-helm.sh no longer labels captured evidence with the deploy-helm reason.'
    }

    $smokeTestScript = Get-Content 'jenkins\scripts\smoke-test.sh' -Raw
    if ($smokeTestScript -notmatch 'capture_runtime_evidence_on_exit') {
        throw 'smoke-test.sh is missing the failure-safe runtime evidence trap.'
    }

    if ($smokeTestScript -notmatch 'CAPTURE_RUNTIME_REASON="smoke-test"') {
        throw 'smoke-test.sh no longer labels captured evidence with the smoke-test reason.'
    }

    $cleanupScript = Get-Content 'jenkins\scripts\cleanup-release.sh' -Raw
    if ($cleanupScript -notmatch 'ENVIRONMENT="\$\{ENVIRONMENT:-developer\}"') {
        throw 'cleanup-release.sh is missing the environment-aware default.'
    }

    if ($cleanupScript -notmatch 'default_namespace "\$ENVIRONMENT" "\$DEPLOYER_ID"') {
        throw 'cleanup-release.sh no longer uses environment-aware namespace defaults.'
    }

    if ($cleanupScript -notmatch 'ALLOW_SHARED_ENVIRONMENT_CLEANUP="\$\{ALLOW_SHARED_ENVIRONMENT_CLEANUP:-0\}"') {
        throw 'cleanup-release.sh is missing the shared-environment cleanup guard.'
    }

    if ($cleanupScript -notmatch 'DELETE_NAMESPACE="\$\{DELETE_NAMESPACE:-\}"') {
        throw 'cleanup-release.sh is missing the optional namespace deletion control.'
    }

    if ($cleanupScript -notmatch 'work/cleanup-evidence') {
        throw 'cleanup-release.sh is missing cleanup evidence artifacts.'
    }

    if ($cleanupScript -notmatch 'yas-dev' -or $cleanupScript -notmatch 'yas-staging') {
        throw 'cleanup-release.sh no longer guards the reserved shared namespace or release names explicitly.'
    }

    if ($cleanupScript -notmatch 'shared_target_detected=') {
        throw 'cleanup-release.sh is missing the shared-target evidence marker.'
    }

    if ($cleanupScript -notmatch 'ALLOW_SHARED_NAMESPACE_DELETE="\$\{ALLOW_SHARED_NAMESPACE_DELETE:-0\}"') {
        throw 'cleanup-release.sh is missing the shared-namespace deletion guard.'
    }

    if ($cleanupScript -notmatch 'Refusing namespace deletion for shared target') {
        throw 'cleanup-release.sh no longer refuses shared namespace deletion without explicit opt-in.'
    }

    $updateManifestRepoScript = Get-Content 'jenkins\scripts\update-manifest-repo.sh' -Raw
    if ($updateManifestRepoScript -notmatch 'BACKOFFICE_DOMAIN_NAME="\$\{BACKOFFICE_DOMAIN_NAME:-backoffice-\$\{ENVIRONMENT\}\.yas\.local\}"') {
        throw 'update-manifest-repo.sh is missing the backoffice GitOps hostname default.'
    }

    if ($updateManifestRepoScript -notmatch 'MANIFEST_METADATA_FILE="\$\{MANIFEST_METADATA_FILE:-work/manifest-update-metadata\.json\}"') {
        throw 'update-manifest-repo.sh is missing the manifest-update metadata artifact.'
    }

    if ($updateManifestRepoScript -notmatch 'mkdir -p "\$\(dirname "\$MANIFEST_METADATA_FILE"\)"') {
        throw 'update-manifest-repo.sh should create the metadata directory when MANIFEST_METADATA_FILE is overridden.'
    }

    if ($updateManifestRepoScript -notmatch 'trap ''write_manifest_metadata \$\?'' EXIT') {
        throw 'update-manifest-repo.sh is missing the failure-safe manifest metadata trap.'
    }

    if ($updateManifestRepoScript -notmatch '"manifest_commit_sha": "\$\{manifest_commit_sha\}"') {
        throw 'update-manifest-repo.sh is missing the manifest commit SHA in its metadata artifact.'
    }

    if ($updateManifestRepoScript -notmatch '"last_action": "\$\{last_action\}"') {
        throw 'update-manifest-repo.sh is missing the final action marker in its metadata artifact.'
    }

    $preflightScript = Get-Content 'scripts\preflight.ps1' -Raw
    if ($preflightScript -notmatch 'docker version') {
        throw 'preflight.ps1 no longer distinguishes Docker CLI presence from daemon access.'
    }

    if ($preflightScript -notmatch 'present but daemon inaccessible') {
        throw 'preflight.ps1 is missing the Docker daemon accessibility status message.'
    }

    if ($preflightJson -notmatch '"type":\s*"validator"') {
        throw 'preflight.ps1 -AsJson is missing validator results.'
    }

    if ($preflightJson -notmatch 'validate-gitops-values') {
        throw 'preflight.ps1 -AsJson is missing the GitOps validator result.'
    }

    Push-Location $tempDir
    try {
        powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\preflight.ps1" -AsJson *> $null
        if ($LASTEXITCODE -eq 0) {
            throw 'preflight.ps1 -AsJson should fail outside the repo root when scaffold files are missing.'
        }
    } finally {
        Pop-Location
    }

    if ($devGeneratedValues -notmatch 'domainName: storefront-dev.yas.local') {
        throw 'Dev generated values are missing the expected storefront dev domain.'
    }

    if ($devGeneratedValues -notmatch 'host: backoffice-dev.yas.local') {
        throw 'Dev generated values are missing the expected backoffice dev host.'
    }

    if ($devGeneratedValues -notmatch 'namespace: yas-dev') {
        throw 'Dev generated values are missing the expected namespace.'
    }

    if ($generatedValues -notmatch 'metricPort: 8090') {
        throw 'Generated values are missing backend metricPort.'
    }

    if ($generatedValues -notmatch 'type: NodePort') {
        throw 'Generated values are missing NodePort exposure.'
    }

    if ($gitopsValues -notmatch 'environment: dev') {
        throw 'Generated GitOps values are missing the expected environment.'
    }

    if ($gitopsValues -notmatch 'payment-paypal:') {
        throw 'Generated GitOps values are missing payment-paypal.'
    }

    if ($gitopsValues -notmatch 'repository: docker\.io/example/yas-storefront') {
        throw 'Generated GitOps values should default to the example registry repository.'
    }

    if ($gitopsNamespaceValues -notmatch 'repository: demo-ns/yas-storefront') {
        throw 'Generated GitOps values should honor the requested Dockerhub namespace.'
    }

    if ($chartValues -notmatch 'repository: docker.io/example/yas-storefront') {
        throw 'Generated chart values are missing the expected storefront repository.'
    }

    if ($chartValues -notmatch 'host: backoffice.yas.local') {
        throw 'Generated chart values are missing the backoffice ingress host.'
    }

    if ($manifestValues -notmatch 'tag: test-tag') {
        throw 'Manifest values update did not apply the expected tag.'
    }

    if ($statusReport -notmatch '## Runtime Access Notes') {
        throw 'Generated status report is missing the runtime access notes section.'
    }

    if ($statusReport -notmatch 'Runtime evidence directories now snapshot commit, manifest, build, push, and verification artifacts') {
        throw 'Generated status report is missing the per-run provenance snapshot note.'
    }

    if ($statusReport -notmatch 'Commit metadata artifacts now embed the exact commit SHA and short SHA directly in `commit-metadata.json`') {
        throw 'Generated status report is missing the self-contained commit metadata note.'
    }

    if ($statusReport -notmatch 'GitOps manifest-update helpers now preserve a dedicated metadata artifact') {
        throw 'Generated status report is missing the manifest-update metadata note.'
    }

    if ($statusReport -notmatch 'Build, push, and remote-tag verification helpers now preserve partial metadata artifacts') {
        throw 'Generated status report is missing the partial build and push metadata note.'
    }

    if ($statusReport -notmatch 'Deploy and smoke-test helpers now capture partial runtime diagnostics') {
        throw 'Generated status report is missing the failure-safe deploy and smoke-test diagnostics note.'
    }

    if ($statusReport -notmatch 'Cleanup helpers now require explicit opt-in for shared targets') {
        throw 'Generated status report is missing the shared-cleanup safety note.'
    }

    powershell -ExecutionPolicy Bypass -File scripts\generate-values.ps1 `
        -ServicesFile 'jenkins\services.release-baseline.env' `
        -OutputFile $generatedValuesFile `
        -DockerhubNamespace $DockerhubNamespace | Out-Null
    $baselineGeneratedValues = Get-Content $generatedValuesFile -Raw
    if ($baselineGeneratedValues -notmatch 'inventory:') {
        throw 'Baseline generated values are missing inventory.'
    }

    if ($baselineGeneratedValues -notmatch "payment:\r?\n\s+enabled: false") {
        throw 'Baseline generated values should disable payment.'
    }

    $previousServiceCatalog = [Environment]::GetEnvironmentVariable('SERVICE_CATALOG')
    [Environment]::SetEnvironmentVariable('SERVICE_CATALOG', 'release-baseline')
    try {
        powershell -ExecutionPolicy Bypass -File scripts\generate-values.ps1 `
            -OutputFile $generatedValuesFile `
            -DockerhubNamespace $DockerhubNamespace | Out-Null
    } finally {
        [Environment]::SetEnvironmentVariable('SERVICE_CATALOG', $previousServiceCatalog)
    }

    $catalogSelectedValues = Get-Content $generatedValuesFile -Raw
    if ($catalogSelectedValues -notmatch "payment:\r?\n\s+enabled: false") {
        throw 'SERVICE_CATALOG=release-baseline did not switch generate-values.ps1 to the baseline catalog.'
    }

    powershell -ExecutionPolicy Bypass -File scripts\generate-gitops-values.ps1 `
        -ServicesFile 'jenkins\services.release-baseline.env' `
        -OutputFile $gitopsValuesFile `
        -EnvironmentName dev | Out-Null
    $baselineGitopsValues = Get-Content $gitopsValuesFile -Raw
    if ($baselineGitopsValues -notmatch "payment:\r?\n\s+enabled: false") {
        throw 'Baseline GitOps values should disable payment.'
    }

    if ($baselineGitopsValues -notmatch 'host: storefront-dev\.yas\.local') {
        throw 'Baseline GitOps values should override the storefront dev ingress host.'
    }

    if ($baselineGitopsValues -notmatch 'host: backoffice-dev\.yas\.local') {
        throw 'Baseline GitOps values should override the backoffice dev ingress host.'
    }

    $committedDevGitopsValues = (Get-Content 'argocd\values\dev-values.yaml' -Raw).Replace("`r`n", "`n").TrimEnd()
    if ($baselineGitopsValues.Replace("`r`n", "`n").TrimEnd() -ne $committedDevGitopsValues) {
        throw 'Committed argocd/values/dev-values.yaml is out of sync with the baseline generator.'
    }

    powershell -ExecutionPolicy Bypass -File scripts\generate-gitops-values.ps1 `
        -ServicesFile 'jenkins\services.release-baseline.env' `
        -OutputFile $gitopsValuesFile `
        -EnvironmentName staging `
        -ReleaseVersion 'v1.0.0' | Out-Null
    $baselineStagingGitopsValues = Get-Content $gitopsValuesFile -Raw
    if ($baselineStagingGitopsValues -notmatch 'host: storefront-staging\.yas\.local') {
        throw 'Baseline GitOps values should override the storefront staging ingress host.'
    }

    if ($baselineStagingGitopsValues -notmatch 'host: backoffice-staging\.yas\.local') {
        throw 'Baseline GitOps values should override the backoffice staging ingress host.'
    }

    $committedStagingGitopsValues = (Get-Content 'argocd\values\staging-values.yaml' -Raw).Replace("`r`n", "`n").TrimEnd()
    if ($baselineStagingGitopsValues.Replace("`r`n", "`n").TrimEnd() -ne $committedStagingGitopsValues) {
        throw 'Committed argocd/values/staging-values.yaml is out of sync with the baseline generator.'
    }

    if ($helmExecutable) {
        & $helmExecutable template yas 'helm\yas' -f 'helm\yas\values.yaml' -f $generatedValuesFile | Out-File -FilePath $baselineHelmRenderFile -Encoding utf8
        $baselineHelmRender = Get-Content $baselineHelmRenderFile -Raw
        if ($baselineHelmRender -match 'name: yas-payment(\r?\n|$)') {
            throw 'Baseline Helm render should not include the payment deployment.'
        }
        if ($baselineHelmRender -match 'name: yas-sampledata(\r?\n|$)') {
            throw 'Baseline Helm render should not include the sampledata deployment.'
        }

        & $helmExecutable template yas-dev 'helm\yas' -f 'helm\yas\values.yaml' -f 'argocd\values\dev-values.yaml' | Out-File -FilePath $gitopsDevHelmRenderFile -Encoding utf8
        $gitopsDevHelmRender = Get-Content $gitopsDevHelmRenderFile -Raw
        if ($gitopsDevHelmRender -notmatch 'host: "storefront-dev\.yas\.local"') {
            throw 'GitOps dev Helm render is missing the storefront dev ingress host override.'
        }
        if ($gitopsDevHelmRender -notmatch 'host: "backoffice-dev\.yas\.local"') {
            throw 'GitOps dev Helm render is missing the backoffice dev ingress host override.'
        }

        & $helmExecutable template yas-staging 'helm\yas' -f 'helm\yas\values.yaml' -f 'argocd\values\staging-values.yaml' | Out-File -FilePath $gitopsStagingHelmRenderFile -Encoding utf8
        $gitopsStagingHelmRender = Get-Content $gitopsStagingHelmRenderFile -Raw
        if ($gitopsStagingHelmRender -notmatch 'host: "storefront-staging\.yas\.local"') {
            throw 'GitOps staging Helm render is missing the storefront staging ingress host override.'
        }
        if ($gitopsStagingHelmRender -notmatch 'host: "backoffice-staging\.yas\.local"') {
            throw 'GitOps staging Helm render is missing the backoffice staging ingress host override.'
        }

        & $helmExecutable template yas-dev 'helm\yas' -f 'helm\yas\values.yaml' -f 'helm\yas\values-dev.yaml' | Out-File -FilePath $sampleDevHelmRenderFile -Encoding utf8
        $sampleDevHelmRender = Get-Content $sampleDevHelmRenderFile -Raw
        if ($sampleDevHelmRender -notmatch 'host: "storefront-dev\.yas\.local"') {
            throw 'helm/yas/values-dev.yaml is missing the storefront dev ingress host override.'
        }
        if ($sampleDevHelmRender -notmatch 'host: "backoffice-dev\.yas\.local"') {
            throw 'helm/yas/values-dev.yaml is missing the backoffice dev ingress host override.'
        }

        & $helmExecutable template yas-staging 'helm\yas' -f 'helm\yas\values.yaml' -f 'helm\yas\values-staging.yaml' | Out-File -FilePath $sampleStagingHelmRenderFile -Encoding utf8
        $sampleStagingHelmRender = Get-Content $sampleStagingHelmRenderFile -Raw
        if ($sampleStagingHelmRender -notmatch 'host: "storefront-staging\.yas\.local"') {
            throw 'helm/yas/values-staging.yaml is missing the storefront staging ingress host override.'
        }
        if ($sampleStagingHelmRender -notmatch 'host: "backoffice-staging\.yas\.local"') {
            throw 'helm/yas/values-staging.yaml is missing the backoffice staging ingress host override.'
        }

        & $helmExecutable template yas-dev1 'helm\yas' -f 'helm\yas\values.yaml' -f 'helm\yas\values-developer-template.yaml' | Out-File -FilePath $sampleDeveloperHelmRenderFile -Encoding utf8
        $sampleDeveloperHelmRender = Get-Content $sampleDeveloperHelmRenderFile -Raw
        if ($sampleDeveloperHelmRender -notmatch 'host: "storefront-dev1\.yas\.local"') {
            throw 'helm/yas/values-developer-template.yaml is missing the storefront developer ingress host override.'
        }
        if ($sampleDeveloperHelmRender -notmatch 'host: "backoffice-dev1\.yas\.local"') {
            throw 'helm/yas/values-developer-template.yaml is missing the backoffice developer ingress host override.'
        }
    }

    if ($helmExecutable -and $helmRender -notmatch 'kind: Deployment') {
        throw 'Helm template output is missing Deployment resources.'
    }

    Write-Host 'Selftest passed.'
    Write-Host "Artifacts were validated under $tempDir"
} finally {
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }
}

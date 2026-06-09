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
$sourceGitBranchTagsFile = Join-Path $tempDir 'source-git-branch-tags.env'
$generatedValuesFile = Join-Path $tempDir 'generated-values.yaml'
$devGeneratedValuesFile = Join-Path $tempDir 'dev-generated-values.yaml'
$gitopsValuesFile = Join-Path $tempDir 'gitops-values.yaml'
$chartValuesFile = Join-Path $tempDir 'chart-values.yaml'
$manifestValuesFile = Join-Path $tempDir 'dev-values.yaml'
$helmRenderFile = Join-Path $tempDir 'helm-render.yaml'
$baselineHelmRenderFile = Join-Path $tempDir 'baseline-helm-render.yaml'
$helmExecutable = Get-HelmExecutable

try {
    Copy-Item 'argocd\values\dev-values.yaml' $manifestValuesFile -Force

    powershell -ExecutionPolicy Bypass -File scripts\validate-services-catalog.ps1 | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\validate-services-catalog.ps1 `
        -ServicesFile 'jenkins\services.release-baseline.env' `
        -ReferenceServicesFile 'jenkins\services.env' | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\validate-chart-values.ps1 | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\validate-gitops-values.ps1 | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\validate-source-alignment.ps1 | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\resolve-branch-tags.ps1 -OutputFile $branchTagsFile | Out-Null

    $previousProductBranch = [Environment]::GetEnvironmentVariable('PRODUCT_BRANCH')
    [Environment]::SetEnvironmentVariable('PRODUCT_BRANCH', 'HEAD')
    try {
        powershell -ExecutionPolicy Bypass -File scripts\resolve-branch-tags.ps1 -SourceGitRoot 'yas-source' -OutputFile $sourceGitBranchTagsFile | Out-Null
    } finally {
        [Environment]::SetEnvironmentVariable('PRODUCT_BRANCH', $previousProductBranch)
    }

    $previousStorefrontBranch = [Environment]::GetEnvironmentVariable('STOREFRONT_BRANCH')
    [Environment]::SetEnvironmentVariable('STOREFRONT_BRANCH', '')
    try {
        powershell -ExecutionPolicy Bypass -File scripts\resolve-branch-tags.ps1 -OutputFile $branchTagsFile | Out-Null
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
    powershell -ExecutionPolicy Bypass -File scripts\generate-chart-values.ps1 `
        -OutputFile $chartValuesFile | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\update-manifest-values.ps1 `
        -ValuesFile $manifestValuesFile `
        -Tag test-tag | Out-Null
    if ($helmExecutable) {
        & $helmExecutable lint 'helm\yas' | Out-Null
        & $helmExecutable template yas 'helm\yas' | Out-File -FilePath $helmRenderFile -Encoding utf8
    }

    $branchTags = Get-Content $branchTagsFile -Raw
    $generatedValues = Get-Content $generatedValuesFile -Raw
    $devGeneratedValues = Get-Content $devGeneratedValuesFile -Raw
    $gitopsValues = Get-Content $gitopsValuesFile -Raw
    $chartValues = Get-Content $chartValuesFile -Raw
    $manifestValues = Get-Content $manifestValuesFile -Raw
    $helmRender = if (Test-Path $helmRenderFile) { Get-Content $helmRenderFile -Raw } else { '' }

    if ($branchTags -notmatch 'TAX_TAG=main') {
        throw 'Branch tag resolution failed for tax service.'
    }

    if ($branchTags -notmatch 'STOREFRONT_TAG=main') {
        throw 'Branch tag resolution should treat empty storefront branch overrides as main.'
    }

    $expectedSourceHead = (& git -C 'yas-source' rev-parse HEAD).Trim()
    $sourceGitBranchTags = Get-Content $sourceGitBranchTagsFile -Raw
    if ($sourceGitBranchTags -notmatch ("PRODUCT_TAG=" + [regex]::Escape($expectedSourceHead))) {
        throw 'Branch tag resolution did not use the expected source Git root.'
    }

    if ($generatedValues -notmatch 'repository: demo-ns/yas-storefront-bff') {
        throw 'Generated values are missing storefront-bff repository.'
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

    if ($jenkinsfile -notmatch 'pipelineRequiresDockerhubNamespace') {
        throw 'Jenkinsfile no longer guards DOCKERHUB_NAMESPACE by pipeline target.'
    }

    if ($jenkinsfile -notmatch "name: 'RELEASE_VERSION'") {
        throw 'Jenkinsfile is missing the shared RELEASE_VERSION parameter.'
    }

    if ($jenkinsfile -notmatch "name: 'DEPLOYER_ID'") {
        throw 'Jenkinsfile is missing the shared DEPLOYER_ID parameter.'
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

    $developerBuildPipeline = Get-Content 'jenkins\pipelines\developer_build.groovy' -Raw
    if ($developerBuildPipeline -notmatch "if \(env\.PIPELINE_DISPATCH_MODE != 'true'\)") {
        throw 'developer_build.groovy no longer skips properties rewrites in dispatch mode.'
    }

    $developerCleanupPipeline = Get-Content 'jenkins\pipelines\developer_cleanup.groovy' -Raw
    if ($developerCleanupPipeline -notmatch "if \(env\.PIPELINE_DISPATCH_MODE != 'true'\)") {
        throw 'developer_cleanup.groovy no longer skips properties rewrites in dispatch mode.'
    }

    $devCdPipeline = Get-Content 'jenkins\pipelines\dev_cd.groovy' -Raw
    if ($devCdPipeline -notmatch "if \(env\.PIPELINE_DISPATCH_MODE != 'true'\)") {
        throw 'dev_cd.groovy no longer skips properties rewrites in dispatch mode.'
    }

    $devGitopsPipeline = Get-Content 'jenkins\pipelines\dev_gitops.groovy' -Raw
    if ($devGitopsPipeline -notmatch "if \(env\.PIPELINE_DISPATCH_MODE != 'true'\)") {
        throw 'dev_gitops.groovy no longer skips properties rewrites in dispatch mode.'
    }

    $stagingGitopsPipeline = Get-Content 'jenkins\pipelines\staging_gitops.groovy' -Raw
    if ($stagingGitopsPipeline -notmatch "if \(env\.PIPELINE_DISPATCH_MODE != 'true'\)") {
        throw 'staging_gitops.groovy no longer skips properties rewrites in dispatch mode.'
    }

    $stagingReleasePipeline = Get-Content 'jenkins\pipelines\staging_release.groovy' -Raw
    if ($stagingReleasePipeline -notmatch "if \(env\.PIPELINE_DISPATCH_MODE != 'true'\)") {
        throw 'staging_release.groovy no longer skips properties rewrites in dispatch mode.'
    }

    $pushImagesScript = Get-Content 'jenkins\scripts\push-images.sh' -Raw
    if ($pushImagesScript -notmatch 'IMAGE_DIGESTS_FILE="work/image-digests.txt"') {
        throw 'push-images.sh is missing the image-digests artifact output.'
    }

    if ($pushImagesScript -notmatch 'record_repo_digest') {
        throw 'push-images.sh no longer records repo digests after push.'
    }

    $cleanupScript = Get-Content 'jenkins\scripts\cleanup-release.sh' -Raw
    if ($cleanupScript -notmatch 'ENVIRONMENT="\$\{ENVIRONMENT:-developer\}"') {
        throw 'cleanup-release.sh is missing the environment-aware default.'
    }

    if ($cleanupScript -notmatch 'default_namespace "\$ENVIRONMENT" "\$DEPLOYER_ID"') {
        throw 'cleanup-release.sh no longer uses environment-aware namespace defaults.'
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

    if ($chartValues -notmatch 'repository: docker.io/example/yas-storefront') {
        throw 'Generated chart values are missing the expected storefront repository.'
    }

    if ($chartValues -notmatch 'host: backoffice.yas.local') {
        throw 'Generated chart values are missing the backoffice ingress host.'
    }

    if ($manifestValues -notmatch 'tag: test-tag') {
        throw 'Manifest values update did not apply the expected tag.'
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

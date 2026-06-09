param(
    [string]$DockerhubNamespace = 'demo-ns'
)

$tempDir = Join-Path $env:TEMP 'yas-scaffold-selftest'
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$branchTagsFile = Join-Path $tempDir 'branch-tags.env'
$generatedValuesFile = Join-Path $tempDir 'generated-values.yaml'
$gitopsValuesFile = Join-Path $tempDir 'gitops-values.yaml'
$chartValuesFile = Join-Path $tempDir 'chart-values.yaml'
$manifestValuesFile = Join-Path $tempDir 'dev-values.yaml'

try {
    Copy-Item 'argocd\values\dev-values.yaml' $manifestValuesFile -Force

    powershell -ExecutionPolicy Bypass -File scripts\validate-services-catalog.ps1 | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\validate-chart-values.ps1 | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\validate-source-alignment.ps1 | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\resolve-branch-tags.ps1 -OutputFile $branchTagsFile | Out-Null
    powershell -ExecutionPolicy Bypass -File scripts\generate-values.ps1 `
        -TagsFile $branchTagsFile `
        -OutputFile $generatedValuesFile `
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

    $branchTags = Get-Content $branchTagsFile -Raw
    $generatedValues = Get-Content $generatedValuesFile -Raw
    $gitopsValues = Get-Content $gitopsValuesFile -Raw
    $chartValues = Get-Content $chartValuesFile -Raw
    $manifestValues = Get-Content $manifestValuesFile -Raw

    if ($branchTags -notmatch 'TAX_TAG=main') {
        throw 'Branch tag resolution failed for tax service.'
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

    Write-Host 'Selftest passed.'
    Write-Host "Artifacts were validated under $tempDir"
} finally {
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }
}

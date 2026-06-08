param(
    [Parameter(Mandatory = $true)]
    [string]$DockerhubNamespace,

    [string]$OutputDir = 'work/dry-run',
    [string]$DeployerId = 'dev1',
    [string]$DomainName = '',
    [string]$TaxBranch = 'main',
    [string]$ProductBranch = 'main',
    [string]$StorefrontBffBranch = 'main'
)

if ([string]::IsNullOrWhiteSpace($DomainName)) {
    $DomainName = "storefront-$DeployerId.yas.local"
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$branchTagsFile = Join-Path $OutputDir 'branch-tags.env'
$generatedValuesFile = Join-Path $OutputDir 'generated-values.yaml'

$previousTaxBranch = $env:TAX_BRANCH
$previousProductBranch = $env:PRODUCT_BRANCH
$previousStorefrontBffBranch = $env:STOREFRONT_BFF_BRANCH

try {
    $env:TAX_BRANCH = $TaxBranch
    $env:PRODUCT_BRANCH = $ProductBranch
    $env:STOREFRONT_BFF_BRANCH = $StorefrontBffBranch

    powershell -ExecutionPolicy Bypass -File scripts\resolve-branch-tags.ps1 -OutputFile $branchTagsFile
    powershell -ExecutionPolicy Bypass -File scripts\generate-values.ps1 `
        -TagsFile $branchTagsFile `
        -OutputFile $generatedValuesFile `
        -DockerhubNamespace $DockerhubNamespace `
        -DeployerId $DeployerId `
        -DomainName $DomainName

    Write-Host ''
    Write-Host 'Generated files:'
    Write-Host "  $branchTagsFile"
    Write-Host "  $generatedValuesFile"
} finally {
    $env:TAX_BRANCH = $previousTaxBranch
    $env:PRODUCT_BRANCH = $previousProductBranch
    $env:STOREFRONT_BFF_BRANCH = $previousStorefrontBffBranch
}


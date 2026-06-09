param(
    [Parameter(Mandatory = $true)]
    [string]$DockerhubNamespace,

    [string]$OutputDir = 'work/dry-run',
    [string]$DeployerId = 'dev1',
    [string]$DomainName = '',
    [string]$BackofficeDomainName = '',
    [ValidateSet('release-baseline', 'full')]
    [string]$ServiceCatalog = 'full',
    [string]$StorefrontBranch = 'main',
    [string]$BackofficeBranch = 'main',
    [string]$StorefrontBffBranch = 'main',
    [string]$BackofficeBffBranch = 'main',
    [string]$ProductBranch = 'main',
    [string]$MediaBranch = 'main',
    [string]$CartBranch = 'main',
    [string]$CustomerBranch = 'main',
    [string]$RatingBranch = 'main',
    [string]$LocationBranch = 'main',
    [string]$OrderBranch = 'main',
    [string]$InventoryBranch = 'main',
    [string]$TaxBranch = 'main',
    [string]$SearchBranch = 'main',
    [string]$PromotionBranch = 'main',
    [string]$PaymentBranch = 'main',
    [string]$PaymentPaypalBranch = 'main',
    [string]$RecommendationBranch = 'main',
    [string]$SampledataBranch = 'main',
    [string]$WebhookBranch = 'main'
)

if ([string]::IsNullOrWhiteSpace($DomainName)) {
    $DomainName = "storefront-$DeployerId.yas.local"
}

if ([string]::IsNullOrWhiteSpace($BackofficeDomainName)) {
    $BackofficeDomainName = "backoffice-$DeployerId.yas.local"
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$branchTagsFile = Join-Path $OutputDir 'branch-tags.env'
$branchTagMetadataFile = Join-Path $OutputDir 'branch-tag-metadata.json'
$generatedValuesFile = Join-Path $OutputDir 'generated-values.yaml'

$branchOverrides = [ordered]@{
    'STOREFRONT_BRANCH'       = $StorefrontBranch
    'BACKOFFICE_BRANCH'       = $BackofficeBranch
    'STOREFRONT_BFF_BRANCH'   = $StorefrontBffBranch
    'BACKOFFICE_BFF_BRANCH'   = $BackofficeBffBranch
    'PRODUCT_BRANCH'          = $ProductBranch
    'MEDIA_BRANCH'            = $MediaBranch
    'CART_BRANCH'             = $CartBranch
    'CUSTOMER_BRANCH'         = $CustomerBranch
    'RATING_BRANCH'           = $RatingBranch
    'LOCATION_BRANCH'         = $LocationBranch
    'ORDER_BRANCH'            = $OrderBranch
    'INVENTORY_BRANCH'        = $InventoryBranch
    'TAX_BRANCH'              = $TaxBranch
    'SEARCH_BRANCH'           = $SearchBranch
    'PROMOTION_BRANCH'        = $PromotionBranch
    'PAYMENT_BRANCH'          = $PaymentBranch
    'PAYMENT_PAYPAL_BRANCH'   = $PaymentPaypalBranch
    'RECOMMENDATION_BRANCH'   = $RecommendationBranch
    'SAMPLEDATA_BRANCH'       = $SampledataBranch
    'WEBHOOK_BRANCH'          = $WebhookBranch
}

$previousBranchOverrides = @{}
foreach ($entry in $branchOverrides.GetEnumerator()) {
    $previousBranchOverrides[$entry.Key] = [Environment]::GetEnvironmentVariable($entry.Key)
}
$previousServiceCatalog = $env:SERVICE_CATALOG

try {
    foreach ($entry in $branchOverrides.GetEnumerator()) {
        [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value)
    }
    $env:SERVICE_CATALOG = $ServiceCatalog

    powershell -ExecutionPolicy Bypass -File scripts\resolve-branch-tags.ps1 -OutputFile $branchTagsFile -MetadataFile $branchTagMetadataFile
    powershell -ExecutionPolicy Bypass -File scripts\generate-values.ps1 `
        -TagsFile $branchTagsFile `
        -OutputFile $generatedValuesFile `
        -DockerhubNamespace $DockerhubNamespace `
        -DeployerId $DeployerId `
        -DomainName $DomainName `
        -BackofficeDomainName $BackofficeDomainName

    Write-Host ''
    Write-Host 'Generated files:'
    Write-Host "  $branchTagsFile"
    Write-Host "  $branchTagMetadataFile"
    Write-Host "  $generatedValuesFile"
} finally {
    foreach ($entry in $previousBranchOverrides.GetEnumerator()) {
        [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value)
    }
    $env:SERVICE_CATALOG = $previousServiceCatalog
}

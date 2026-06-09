param(
    [string]$DevAppFile = 'argocd/app-dev.yaml',
    [string]$StagingAppFile = 'argocd/app-staging.yaml'
)

function Assert-Match {
    param(
        [string]$Content,
        [string]$Pattern,
        [string]$Message
    )

    if ($Content -notmatch $Pattern) {
        Write-Error $Message
        exit 1
    }
}

function Test-AppFile {
    param(
        [string]$FilePath,
        [string]$ExpectedName,
        [string]$ExpectedValuesFile,
        [string]$ExpectedNamespace
    )

    if (-not (Test-Path $FilePath)) {
        Write-Error "ArgoCD application file not found: $FilePath"
        exit 1
    }

    $content = Get-Content $FilePath -Raw

    Assert-Match -Content $content -Pattern '(?m)^kind:\s+Application\s*$' -Message "ArgoCD application kind mismatch in $FilePath"
    Assert-Match -Content $content -Pattern ("(?m)^  name:\s+" + [regex]::Escape($ExpectedName) + "\s*$") -Message "ArgoCD metadata.name mismatch in $FilePath"
    Assert-Match -Content $content -Pattern '(?m)^  namespace:\s+argocd\s*$' -Message "ArgoCD metadata.namespace should stay argocd in $FilePath"
    Assert-Match -Content $content -Pattern '(?m)^    path:\s+helm/yas\s*$' -Message "ArgoCD source.path should stay helm/yas in $FilePath"
    Assert-Match -Content $content -Pattern ('(?m)^\s*-\s+' + [regex]::Escape($ExpectedValuesFile) + '\s*$') -Message "ArgoCD values file mismatch in $FilePath"
    Assert-Match -Content $content -Pattern '(?m)^    server:\s+https://kubernetes\.default\.svc\s*$' -Message "ArgoCD destination.server mismatch in $FilePath"
    Assert-Match -Content $content -Pattern ("(?m)^    namespace:\s+" + [regex]::Escape($ExpectedNamespace) + "\s*$") -Message "ArgoCD destination.namespace mismatch in $FilePath"
}

Test-AppFile -FilePath $DevAppFile -ExpectedName 'yas-dev' -ExpectedValuesFile '../../argocd/values/dev-values.yaml' -ExpectedNamespace 'yas-dev'
Test-AppFile -FilePath $StagingAppFile -ExpectedName 'yas-staging' -ExpectedValuesFile '../../argocd/values/staging-values.yaml' -ExpectedNamespace 'yas-staging'

Write-Host "ArgoCD application manifests are valid: $DevAppFile and $StagingAppFile"

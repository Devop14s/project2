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
        [string]$ExpectedRepoUrl,
        [string]$ExpectedTargetRevision,
        [string]$ExpectedValuesFile,
        [string]$ExpectedNamespace,
        [string]$ExpectedProject = 'default',
        [bool]$RequireAutomatedSync = $false
    )

    if (-not (Test-Path $FilePath)) {
        Write-Error "ArgoCD application file not found: $FilePath"
        exit 1
    }

    $content = Get-Content $FilePath -Raw

    Assert-Match -Content $content -Pattern '(?m)^apiVersion:\s+argoproj\.io/v1alpha1\s*$' -Message "ArgoCD apiVersion mismatch in $FilePath"
    Assert-Match -Content $content -Pattern '(?m)^kind:\s+Application\s*$' -Message "ArgoCD application kind mismatch in $FilePath"
    Assert-Match -Content $content -Pattern ("(?m)^  name:\s+" + [regex]::Escape($ExpectedName) + "\s*$") -Message "ArgoCD metadata.name mismatch in $FilePath"
    Assert-Match -Content $content -Pattern '(?m)^  namespace:\s+argocd\s*$' -Message "ArgoCD metadata.namespace should stay argocd in $FilePath"
    Assert-Match -Content $content -Pattern ("(?m)^  project:\s+" + [regex]::Escape($ExpectedProject) + "\s*$") -Message "ArgoCD project mismatch in $FilePath"
    Assert-Match -Content $content -Pattern ("(?m)^    repoURL:\s+" + [regex]::Escape($ExpectedRepoUrl) + "\s*$") -Message "ArgoCD repoURL mismatch in $FilePath"
    Assert-Match -Content $content -Pattern ("(?m)^    targetRevision:\s+" + [regex]::Escape($ExpectedTargetRevision) + "\s*$") -Message "ArgoCD targetRevision mismatch in $FilePath"
    Assert-Match -Content $content -Pattern '(?m)^    path:\s+helm/yas\s*$' -Message "ArgoCD source.path should stay helm/yas in $FilePath"
    Assert-Match -Content $content -Pattern ('(?m)^\s*-\s+' + [regex]::Escape($ExpectedValuesFile) + '\s*$') -Message "ArgoCD values file mismatch in $FilePath"
    Assert-Match -Content $content -Pattern '(?m)^    server:\s+https://kubernetes\.default\.svc\s*$' -Message "ArgoCD destination.server mismatch in $FilePath"
    Assert-Match -Content $content -Pattern ("(?m)^    namespace:\s+" + [regex]::Escape($ExpectedNamespace) + "\s*$") -Message "ArgoCD destination.namespace mismatch in $FilePath"
    Assert-Match -Content $content -Pattern '(?m)^\s*-\s+CreateNamespace=true\s*$' -Message "ArgoCD syncOptions should keep CreateNamespace=true in $FilePath"

    if ($RequireAutomatedSync) {
        Assert-Match -Content $content -Pattern '(?m)^    automated:\s*$' -Message "ArgoCD automated sync block is missing in $FilePath"
        Assert-Match -Content $content -Pattern '(?m)^      prune:\s+true\s*$' -Message "ArgoCD automated prune=true is missing in $FilePath"
        Assert-Match -Content $content -Pattern '(?m)^      selfHeal:\s+true\s*$' -Message "ArgoCD automated selfHeal=true is missing in $FilePath"
    } elseif ($content -match '(?m)^    automated:\s*$') {
        Write-Error "ArgoCD staging manifest should remain manual-sync in $FilePath"
        exit 1
    }
}

Test-AppFile -FilePath $DevAppFile -ExpectedName 'yas-dev' -ExpectedRepoUrl 'https://github.com/Devop14s/project2.git' -ExpectedTargetRevision 'main' -ExpectedValuesFile '../../argocd/values/dev-values.yaml' -ExpectedNamespace 'yas-dev' -RequireAutomatedSync $true
Test-AppFile -FilePath $StagingAppFile -ExpectedName 'yas-staging' -ExpectedRepoUrl 'https://github.com/Devop14s/project2.git' -ExpectedTargetRevision 'main' -ExpectedValuesFile '../../argocd/values/staging-values.yaml' -ExpectedNamespace 'yas-staging'

Write-Host "ArgoCD application manifests are valid: $DevAppFile and $StagingAppFile"

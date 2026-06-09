param(
    [string]$ServicesFile = 'jenkins/services.release-baseline.env',
    [string]$DevValuesFile = 'argocd/values/dev-values.yaml',
    [string]$StagingValuesFile = 'argocd/values/staging-values.yaml',
    [string]$StagingReleaseVersion = 'v1.0.0'
)

if (-not (Test-Path $DevValuesFile)) {
    Write-Error "Dev values file not found: $DevValuesFile"
    exit 1
}

if (-not (Test-Path $StagingValuesFile)) {
    Write-Error "Staging values file not found: $StagingValuesFile"
    exit 1
}

$tempDir = Join-Path $env:TEMP ("yas-gitops-values-" + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$expectedDevValuesFile = Join-Path $tempDir 'dev-values.yaml'
$expectedStagingValuesFile = Join-Path $tempDir 'staging-values.yaml'

try {
    powershell -ExecutionPolicy Bypass -File scripts\generate-gitops-values.ps1 `
        -ServicesFile $ServicesFile `
        -EnvironmentName dev `
        -OutputFile $expectedDevValuesFile | Out-Null

    powershell -ExecutionPolicy Bypass -File scripts\generate-gitops-values.ps1 `
        -ServicesFile $ServicesFile `
        -EnvironmentName staging `
        -ReleaseVersion $StagingReleaseVersion `
        -OutputFile $expectedStagingValuesFile | Out-Null

    $expectedDev = (Get-Content $expectedDevValuesFile -Raw).Replace("`r`n", "`n").TrimEnd()
    $actualDev = (Get-Content $DevValuesFile -Raw).Replace("`r`n", "`n").TrimEnd()
    if ($expectedDev -ne $actualDev) {
        Write-Error "GitOps dev values drift detected between $ServicesFile and $DevValuesFile"
        exit 1
    }

    $expectedStaging = (Get-Content $expectedStagingValuesFile -Raw).Replace("`r`n", "`n").TrimEnd()
    $actualStaging = (Get-Content $StagingValuesFile -Raw).Replace("`r`n", "`n").TrimEnd()
    if ($expectedStaging -ne $actualStaging) {
        Write-Error "GitOps staging values drift detected between $ServicesFile and $StagingValuesFile"
        exit 1
    }

    Write-Host "GitOps values are in sync: $DevValuesFile and $StagingValuesFile"
} finally {
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }
}

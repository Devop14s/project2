param(
    [string]$ServicesFile = 'jenkins/services.env',
    [string]$ValuesFile = 'helm/yas/values.yaml'
)

if (-not (Test-Path $ValuesFile)) {
    Write-Error "Values file not found: $ValuesFile"
    exit 1
}

$tempFile = Join-Path $env:TEMP ("yas-chart-values-" + [guid]::NewGuid().ToString() + ".yaml")

try {
    powershell -ExecutionPolicy Bypass -File scripts\generate-chart-values.ps1 `
        -ServicesFile $ServicesFile `
        -OutputFile $tempFile | Out-Null

    $expected = (Get-Content $tempFile -Raw).Replace("`r`n", "`n").TrimEnd()
    $actual = (Get-Content $ValuesFile -Raw).Replace("`r`n", "`n").TrimEnd()

    if ($expected -ne $actual) {
        Write-Error "Chart values drift detected between $ServicesFile and $ValuesFile"
        exit 1
    }

    Write-Host "Chart values are in sync: $ValuesFile"
} finally {
    if (Test-Path $tempFile) {
        Remove-Item $tempFile -Force
    }
}

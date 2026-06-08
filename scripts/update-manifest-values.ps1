param(
    [Parameter(Mandatory = $true)]
    [string]$ValuesFile,

    [Parameter(Mandatory = $true)]
    [string]$Tag
)

if (-not (Test-Path $ValuesFile)) {
    Write-Error "Values file not found: $ValuesFile"
    exit 1
}

$lines = Get-Content $ValuesFile
$output = New-Object System.Collections.Generic.List[string]
$inImageBlock = $false

foreach ($line in $lines) {
    $trimmed = $line.TrimStart()

    if ($trimmed -eq 'image:') {
        $inImageBlock = $true
        $output.Add($line)
        continue
    }

    if ($inImageBlock -and $trimmed -match '^tag:\s*') {
        $indentLength = $line.Length - $trimmed.Length
        $indent = ' ' * $indentLength
        $output.Add("${indent}tag: $Tag")
        $inImageBlock = $false
        continue
    }

    if ($trimmed -and -not $line.StartsWith(' ')) {
        $inImageBlock = $false
    }

    $output.Add($line)
}

[System.IO.File]::WriteAllLines((Resolve-Path $ValuesFile), $output)
Write-Host "Updated $ValuesFile with tag $Tag"


param(
    [string]$ServicesFile = 'jenkins/services.env'
)

if (-not (Test-Path $ServicesFile)) {
    Write-Error "Services file not found: $ServicesFile"
    exit 1
}

$seen = @{}
$seenNodePorts = @{}
$errors = New-Object System.Collections.Generic.List[string]
$lines = Get-Content $ServicesFile
$lineNumber = 0

foreach ($line in $lines) {
    $lineNumber += 1

    if (-not $line) { continue }
    if ($line.StartsWith('#')) { continue }

    $parts = $line.Split('|')
    if ($parts.Count -ne 7) {
        $errors.Add("Line $lineNumber must have 7 columns separated by |")
        continue
    }

    $service = $parts[0]
    $path = $parts[1]
    $dockerfile = $parts[2]
    $port = $parts[3]
    $expose = $parts[4]
    $nodePort = $parts[5]
    $workloadType = $parts[6]

    if ([string]::IsNullOrWhiteSpace($service)) {
        $errors.Add("Line $lineNumber has an empty service name")
    } elseif ($seen.ContainsKey($service)) {
        $errors.Add("Duplicate service name: $service")
    } else {
        $seen[$service] = $true
    }

    if ([string]::IsNullOrWhiteSpace($path)) {
        $errors.Add("Line $lineNumber has an empty repo path")
    }

    if ([string]::IsNullOrWhiteSpace($dockerfile)) {
        $errors.Add("Line $lineNumber has an empty Dockerfile path")
    }

    if ($port -notmatch '^\d+$') {
        $errors.Add("Line $lineNumber has a non-numeric port: $port")
    }

    if ($expose -notin @('true', 'false')) {
        $errors.Add("Line $lineNumber expose value must be true or false")
    }

    if ($expose -eq 'true') {
        if ([string]::IsNullOrWhiteSpace($nodePort)) {
            $errors.Add("Line $lineNumber must provide nodePort when expose=true")
        } elseif ($nodePort -notmatch '^\d+$') {
            $errors.Add("Line $lineNumber has a non-numeric nodePort: $nodePort")
        } elseif ($seenNodePorts.ContainsKey($nodePort)) {
            $errors.Add("Duplicate nodePort detected: $nodePort")
        } else {
            $seenNodePorts[$nodePort] = $true
        }
    }

    if ($workloadType -notin @('ui', 'backend')) {
        $errors.Add("Line $lineNumber workloadType must be ui or backend")
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    exit 1
}

Write-Host "Service catalog is valid: $ServicesFile"

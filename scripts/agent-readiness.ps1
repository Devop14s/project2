param(
    [switch]$AsJson
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

function Get-ToolStatus {
    param(
        [string]$Name,
        [string]$ExplicitPath
    )

    $resolvedPath = $ExplicitPath
    if (-not $resolvedPath) {
        $command = Get-Command $Name -ErrorAction SilentlyContinue
        if ($command) {
            $resolvedPath = $command.Source
        }
    }

    if (-not $resolvedPath) {
        return [pscustomobject]@{
            type = 'tool'
            name = $Name
            status = 'missing'
            detail = ''
        }
    }

    return [pscustomobject]@{
        type = 'tool'
        name = $Name
        status = 'ok'
        detail = $resolvedPath
    }
}

function Invoke-Check {
    param(
        [string]$Name,
        [scriptblock]$Script,
        [switch]$Required
    )

    try {
        & $Script
        return [pscustomobject]@{
            type = 'check'
            name = $Name
            status = 'ok'
            required = $Required.IsPresent
            detail = ''
        }
    } catch {
        return [pscustomobject]@{
            type = 'check'
            name = $Name
            status = 'failed'
            required = $Required.IsPresent
            detail = $_.Exception.Message
        }
    }
}

$helmPath = Get-HelmExecutable
$results = @(
    Get-ToolStatus -Name 'git',
    Get-ToolStatus -Name 'bash',
    Get-ToolStatus -Name 'docker',
    Get-ToolStatus -Name 'kubectl',
    Get-ToolStatus -Name 'helm' -ExplicitPath $helmPath
)

$results += Invoke-Check -Name 'docker-daemon' -Required -Script {
    docker version *> $null
    if ($LASTEXITCODE -ne 0) {
        throw 'Docker CLI is present but daemon is unreachable.'
    }
}

$results += Invoke-Check -Name 'kubectl-client' -Required -Script {
    kubectl version --client *> $null
    if ($LASTEXITCODE -ne 0) {
        throw 'kubectl client check failed.'
    }
}

$results += Invoke-Check -Name 'helm-client' -Required -Script {
    if ($helmPath) {
        & $helmPath version *> $null
        if ($LASTEXITCODE -ne 0) {
            throw 'Helm version check failed.'
        }
    } else {
        throw 'Helm executable was not found.'
    }
}

$results += Invoke-Check -Name 'dockerhub-namespace' -Script {
    $namespace = [Environment]::GetEnvironmentVariable('DOCKERHUB_NAMESPACE')
    if ([string]::IsNullOrWhiteSpace($namespace)) {
        throw 'DOCKERHUB_NAMESPACE is not set in the current environment.'
    }
}

$results += Invoke-Check -Name 'kubeconfig-env' -Script {
    $kubeconfig = [Environment]::GetEnvironmentVariable('KUBECONFIG')
    if ([string]::IsNullOrWhiteSpace($kubeconfig)) {
        throw 'KUBECONFIG is not set in the current environment.'
    }
}

$results += Invoke-Check -Name 'cluster-connectivity' -Script {
    $kubeconfig = [Environment]::GetEnvironmentVariable('KUBECONFIG')
    if ([string]::IsNullOrWhiteSpace($kubeconfig)) {
        throw 'KUBECONFIG is not set, so cluster connectivity cannot be checked yet.'
    }

    kubectl get ns *> $null
    if ($LASTEXITCODE -ne 0) {
        throw 'kubectl get ns failed.'
    }
}

if ($AsJson) {
    $results | ConvertTo-Json -Depth 3
    if ($results | Where-Object { $_.required -and $_.status -ne 'ok' }) {
        exit 1
    }
    exit 0
}

$results | Format-Table -AutoSize

$requiredFailures = $results | Where-Object { $_.required -and $_.status -ne 'ok' }
if ($requiredFailures) {
    Write-Host ''
    Write-Host 'Required agent-readiness checks failed.' -ForegroundColor Yellow
    exit 1
}

Write-Host ''
Write-Host 'Required agent-readiness checks passed.' -ForegroundColor Green

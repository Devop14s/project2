function Resolve-SourceRoot {
    param([string]$SourceRoot)

    if (-not [string]::IsNullOrWhiteSpace($SourceRoot)) {
        return $SourceRoot
    }

    $envSourceRoot = [Environment]::GetEnvironmentVariable('SOURCE_ROOT')
    if (-not [string]::IsNullOrWhiteSpace($envSourceRoot)) {
        return $envSourceRoot
    }

    if (Test-Path 'yas-source') {
        return 'yas-source'
    }

    return '.'
}

function Resolve-SourceGitRoot {
    param(
        [string]$SourceGitRoot,
        [string]$SourceRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($SourceGitRoot)) {
        return $SourceGitRoot
    }

    $envSourceGitRoot = [Environment]::GetEnvironmentVariable('SOURCE_GIT_ROOT')
    if (-not [string]::IsNullOrWhiteSpace($envSourceGitRoot)) {
        return $envSourceGitRoot
    }

    $resolvedSourceRoot = Resolve-SourceRoot -SourceRoot $SourceRoot
    if (Test-Path (Join-Path $resolvedSourceRoot '.git')) {
        return $resolvedSourceRoot
    }

    return '.'
}

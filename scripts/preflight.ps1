param(
    [switch]$AsJson,
    [switch]$SkipCommandChecks
)

function Test-ToolAvailable {
    param(
        [string]$CommandName
    )

    if ($null -ne (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
        return $true
    }

    if ($CommandName -eq 'helm') {
        $localHelm = Get-ChildItem -Path 'work\tools' -Filter 'helm.exe' -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -like '*windows-amd64*' } |
            Select-Object -First 1
        return $null -ne $localHelm
    }

    return $false
}

function Get-CommandStatus {
    param(
        [string]$CommandName
    )

    $exists = Test-ToolAvailable -CommandName $CommandName
    if (-not $exists) {
        return 'missing'
    }

    if ($CommandName -eq 'docker') {
        try {
            docker version *> $null
            if ($LASTEXITCODE -eq 0) {
                return 'ok'
            }
        } catch {
        }

        return 'present but daemon inaccessible'
    }

    return 'ok'
}

$requiredFiles = @(
    'README.md',
    'Jenkinsfile',
    'jenkins\README.md',
    'jenkins\services.env',
    'jenkins\services.release-baseline.env',
    'jenkins\pipelines\ci.groovy',
    'jenkins\pipelines\developer_build.groovy',
    'jenkins\pipelines\developer_cleanup.groovy',
    'jenkins\pipelines\dev_cd.groovy',
    'jenkins\pipelines\dev_gitops.groovy',
    'jenkins\pipelines\staging_release.groovy',
    'jenkins\pipelines\staging_gitops.groovy',
    'jenkins\scripts\build-images.sh',
    'jenkins\scripts\capture-runtime-evidence.sh',
    'jenkins\scripts\cleanup-release.sh',
    'jenkins\scripts\common.sh',
    'jenkins\scripts\deploy-helm.sh',
    'jenkins\scripts\docker-login.sh',
    'jenkins\scripts\generate-values.sh',
    'jenkins\scripts\push-images.sh',
    'jenkins\scripts\resolve-branch-tags.sh',
    'jenkins\scripts\smoke-test.sh',
    'jenkins\scripts\update-manifest-repo.sh',
    'jenkins\scripts\verify-image-tags.sh',
    'jenkins\scripts\write-commit-metadata.sh',
    'helm\yas\Chart.yaml',
    'helm\yas\values-dev.yaml',
    'helm\yas\values-staging.yaml',
    'helm\yas\values-developer-template.yaml',
    'helm\yas\values.yaml',
    'docs\status-report.md',
    'argocd\app-dev.yaml',
    'argocd\app-staging.yaml',
    'argocd\values\dev-values.yaml',
    'argocd\values\staging-values.yaml',
    'mesh\authorization-policy.yaml',
    'mesh\destination-rule.yaml',
    'mesh\peer-authentication.yaml',
    'mesh\virtual-service-retry.yaml',
    'scripts\preflight.ps1',
    'scripts\preflight.sh',
    'scripts\developer-build-dry-run.ps1',
    'scripts\developer-build-dry-run.sh',
    'scripts\catalog.ps1',
    'scripts\catalog.sh',
    'scripts\source-root.ps1',
    'scripts\source-root.sh',
    'scripts\selftest.ps1',
    'scripts\selftest.sh',
    'scripts\validate-services-catalog.ps1',
    'scripts\validate-services-catalog.sh',
    'scripts\validate-argocd-readme.ps1',
    'scripts\validate-argocd-readme.sh',
    'scripts\validate-argocd-apps.ps1',
    'scripts\validate-argocd-apps.sh',
    'scripts\validate-handover-checklist.ps1',
    'scripts\validate-handover-checklist.sh',
    'scripts\validate-chart-values.ps1',
    'scripts\validate-chart-values.sh',
    'scripts\validate-final-report-template.ps1',
    'scripts\validate-final-report-template.sh',
    'scripts\validate-jenkins-readme.ps1',
    'scripts\validate-jenkins-readme.sh',
    'scripts\validate-image-matrix.ps1',
    'scripts\validate-image-matrix.sh',
    'scripts\validate-mesh-readme.ps1',
    'scripts\validate-mesh-readme.sh',
    'scripts\validate-operations-docs.ps1',
    'scripts\validate-operations-docs.sh',
    'scripts\validate-readme.ps1',
    'scripts\validate-readme.sh',
    'scripts\validate-service-inventory.ps1',
    'scripts\validate-service-inventory.sh',
    'scripts\validate-troubleshooting.ps1',
    'scripts\validate-troubleshooting.sh',
    'scripts\validate-remaining-work-plan.ps1',
    'scripts\validate-remaining-work-plan.sh',
    'scripts\validate-gitops-values.ps1',
    'scripts\validate-gitops-values.sh',
    'scripts\validate-source-alignment.ps1',
    'scripts\validate-source-alignment.sh',
    'scripts\validate-source-build-runtime-matrix.ps1',
    'scripts\validate-source-build-runtime-matrix.sh',
    'scripts\validate-status-report.ps1',
    'scripts\validate-status-report.sh',
    'scripts\summarize-failsafe-blockers.ps1',
    'scripts\summarize-failsafe-blockers.sh',
    'scripts\generate-service-verification-matrix.ps1',
    'scripts\generate-service-verification-matrix.sh',
    'scripts\workspace-blocker-overrides.txt',
    'scripts\report-status.ps1',
    'scripts\report-status.sh',
    'scripts\resolve-branch-tags.ps1',
    'scripts\resolve-branch-tags.sh',
    'scripts\generate-values.ps1',
    'scripts\generate-values.sh',
    'scripts\generate-gitops-values.ps1',
    'scripts\generate-gitops-values.sh',
    'scripts\generate-chart-values.ps1',
    'scripts\generate-chart-values.sh',
    'scripts\update-manifest-values.ps1',
    'scripts\update-manifest-values.sh'
)

$requiredCommands = @(
    'git',
    'kubectl',
    'helm',
    'docker'
)

$validatorDefinitions = @(
    @{
        name = 'validate-services-catalog/full'
        script = 'scripts\validate-services-catalog.ps1'
        arguments = @()
    },
    @{
        name = 'validate-services-catalog/release-baseline'
        script = 'scripts\validate-services-catalog.ps1'
        arguments = @('-ServicesFile', 'jenkins\services.release-baseline.env', '-ReferenceServicesFile', 'jenkins\services.env')
    },
    @{
        name = 'validate-argocd-readme'
        script = 'scripts\validate-argocd-readme.ps1'
        arguments = @()
    },
    @{
        name = 'validate-argocd-apps'
        script = 'scripts\validate-argocd-apps.ps1'
        arguments = @()
    },
    @{
        name = 'validate-handover-checklist'
        script = 'scripts\validate-handover-checklist.ps1'
        arguments = @()
    },
    @{
        name = 'validate-chart-values'
        script = 'scripts\validate-chart-values.ps1'
        arguments = @()
    },
    @{
        name = 'validate-final-report-template'
        script = 'scripts\validate-final-report-template.ps1'
        arguments = @()
    },
    @{
        name = 'validate-jenkins-readme'
        script = 'scripts\validate-jenkins-readme.ps1'
        arguments = @()
    },
    @{
        name = 'validate-image-matrix'
        script = 'scripts\validate-image-matrix.ps1'
        arguments = @()
    },
    @{
        name = 'validate-mesh-readme'
        script = 'scripts\validate-mesh-readme.ps1'
        arguments = @()
    },
    @{
        name = 'validate-operations-docs'
        script = 'scripts\validate-operations-docs.ps1'
        arguments = @()
    },
    @{
        name = 'validate-readme'
        script = 'scripts\validate-readme.ps1'
        arguments = @()
    },
    @{
        name = 'validate-service-inventory'
        script = 'scripts\validate-service-inventory.ps1'
        arguments = @()
    },
    @{
        name = 'validate-troubleshooting'
        script = 'scripts\validate-troubleshooting.ps1'
        arguments = @()
    },
    @{
        name = 'validate-remaining-work-plan'
        script = 'scripts\validate-remaining-work-plan.ps1'
        arguments = @()
    },
    @{
        name = 'validate-gitops-values'
        script = 'scripts\validate-gitops-values.ps1'
        arguments = @()
    },
    @{
        name = 'validate-source-alignment'
        script = 'scripts\validate-source-alignment.ps1'
        arguments = @()
    },
    @{
        name = 'validate-source-build-runtime-matrix'
        script = 'scripts\validate-source-build-runtime-matrix.ps1'
        arguments = @()
    },
    @{
        name = 'validate-status-report'
        script = 'scripts\validate-status-report.ps1'
        arguments = @()
    }
)

$fileResults = foreach ($file in $requiredFiles) {
    [pscustomobject]@{
        type = 'file'
        name = $file
        status = if (Test-Path $file) { 'ok' } else { 'missing' }
    }
}

$commandResults = foreach ($cmd in $requiredCommands) {
    [pscustomobject]@{
        type = 'command'
        name = $cmd
        status = Get-CommandStatus -CommandName $cmd
    }
}

$results = @($fileResults)
if (-not $SkipCommandChecks) {
    $results += $commandResults
}

$validatorResults = foreach ($validator in $validatorDefinitions) {
    $status = 'failed'
    if (-not (Test-Path $validator.script)) {
        $status = 'missing'
    } else {
        try {
            $null = & powershell -ExecutionPolicy Bypass -File $validator.script @($validator.arguments) *> $null
            if ($LASTEXITCODE -eq 0) {
                $status = 'ok'
            }
        } catch {
            $status = 'failed'
        }
    }

    [pscustomobject]@{
        type = 'validator'
        name = $validator.name
        status = $status
    }
}

$results += $validatorResults

$missing = $results | Where-Object { $_.status -ne 'ok' }

if ($AsJson) {
    $results | ConvertTo-Json -Depth 3
    if ($missing) {
        exit 1
    }
    exit 0
}

$results | Format-Table -AutoSize

if ($missing) {
    Write-Host ''
    Write-Host 'Missing items detected.' -ForegroundColor Yellow
    exit 1
}

Write-Host ''
Write-Host 'All scaffold preflight checks passed.' -ForegroundColor Green

param(
    [string]$OutputFile = 'work/final-report-notes.generated.md',
    [string]$StatusReportFile = 'work/status-report.generated.md',
    [string]$ServiceVerificationFile = 'work/service-verification.generated.md',
    [string]$HostCapabilitiesFile = 'work/host-capabilities.generated.md',
    [string]$BaselineServicesFile = 'jenkins/services.release-baseline.env'
)

$outputDir = Split-Path -Parent $OutputFile
if ($outputDir) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$resolvedOutputPath = if ([System.IO.Path]::IsPathRooted($OutputFile)) {
    $OutputFile
} else {
    Join-Path (Get-Location) $OutputFile
}

$baselineServices = New-Object System.Collections.Generic.List[string]
foreach ($line in Get-Content $BaselineServicesFile) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
        continue
    }

    $parts = $line.Split('|')
    if ($parts.Count -ge 1) {
        $service = $parts[0].Trim()
        if (-not [string]::IsNullOrWhiteSpace($service)) {
            $baselineServices.Add($service)
        }
    }
}

$blockerLines = @(powershell -ExecutionPolicy Bypass -File scripts\summarize-failsafe-blockers.ps1)
$compileBlocked = New-Object System.Collections.Generic.List[string]
$keycloakBlocked = New-Object System.Collections.Generic.List[string]
$elasticsearchBlocked = New-Object System.Collections.Generic.List[string]
$otherBlocked = New-Object System.Collections.Generic.List[string]

foreach ($blockerLine in $blockerLines) {
    $parts = $blockerLine -split '\|', 4
    if ($parts.Count -lt 4) {
        continue
    }

    $service = $parts[0]
    $category = $parts[1]
    $message = $parts[3]

    if ($category -eq 'compile') {
        $compileBlocked.Add($service)
    } elseif ($category -eq 'keycloak') {
        $keycloakBlocked.Add($service)
    } elseif ($category -eq 'elasticsearch') {
        $elasticsearchBlocked.Add($service)
    } else {
        $otherBlocked.Add("${service}: $message")
    }
}

$content = New-Object System.Collections.Generic.List[string]
$content.Add('# Final Report Notes')
$content.Add('')
$content.Add("Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$content.Add('')
$content.Add('Use this file as a prefilled drafting aid alongside [docs/final-report-template.md](../docs/final-report-template.md).')
$content.Add('')
$content.Add('## Recommended First Release Subset')
foreach ($service in $baselineServices) {
    $content.Add('- `' + $service + '`')
}
$content.Add('')
$content.Add('## What Is Already Verified Locally')
$content.Add('- Source-verified delivery scaffold exists for Jenkins, Helm, ArgoCD, and service mesh.')
$content.Add('- Local build evidence exists for the UI services `storefront` and `backoffice`.')
$content.Add('- Full upstream-style Maven build evidence exists for `storefront-bff`, `backoffice-bff`, `product`, `payment`, `payment-paypal`, `recommendation`, `inventory`, and `order`.')
$content.Add('- Package or build-artifact evidence exists for `cart`, `customer`, `location`, `media`, `promotion`, `rating`, `tax`, `webhook`, `sampledata`, and `search`.')
$content.Add('- Helm chart lint and template rendering were verified locally.')
$content.Add('- Generated evidence files are refreshed together by `powershell -ExecutionPolicy Bypass -File scripts\refresh-evidence.ps1 -SkipCommandChecks`.')
$content.Add('')
$content.Add('## Known Gaps To State Explicitly')
$content.Add('- No real registry push has been verified yet.')
$content.Add('- No real Kubernetes deployment has been verified yet.')
$content.Add('- Jenkins credentials, webhooks, registry wiring, and kubeconfig access have not been exercised end to end.')
if ($compileBlocked.Count -gt 0) {
    $content.Add('- Compile-path blockers:')
    foreach ($service in ($compileBlocked | Sort-Object -Unique)) {
        $content.Add('  - `' + $service + '`')
    }
}
if ($elasticsearchBlocked.Count -gt 0) {
    $content.Add('- Elasticsearch/Testcontainers blockers:')
    foreach ($service in ($elasticsearchBlocked | Sort-Object -Unique)) {
        $content.Add('  - `' + $service + '`')
    }
}
if ($keycloakBlocked.Count -gt 0) {
    $content.Add('- Keycloak/Testcontainers blockers:')
    foreach ($service in ($keycloakBlocked | Sort-Object -Unique)) {
        $content.Add('  - `' + $service + '`')
    }
}
foreach ($item in ($otherBlocked | Sort-Object -Unique)) {
    $content.Add("- Other blocker: $item")
}
$content.Add('')
$content.Add('## Evidence Files To Reuse In The Report')
$content.Add('- `work/status-report.generated.md`')
$content.Add('- `work/service-verification.generated.md`')
$content.Add('- `work/host-capabilities.generated.md`')
$content.Add('- `docs/source-build-runtime-matrix.md`')
$content.Add('- `docs/image-matrix.md`')
$content.Add('- `work/image-digests.txt` after a real push run')
$content.Add('- `work/commit-metadata.json` after `dev` or `staging` promotion runs')
$content.Add('- `work/runtime-evidence/<namespace>/<release>/` after deploy or smoke-test runs')
$content.Add('- `work/cleanup-evidence/<namespace>/<release>/` after cleanup runs')
$content.Add('- `work/manifest-update-metadata.json` after GitOps manifest-update runs')
$content.Add('')
$content.Add('## Suggested Wording For The Conclusion')
$content.Add('- Verified locally only: scaffold structure, source alignment, catalog generation, local builds, local image builds where available, and Helm rendering.')
$content.Add('- Current host capability evidence: `work/host-capabilities.generated.md` shows which tools and runtime dependencies were actually reachable while the local evidence bundle was generated.')
$content.Add('- Verified end to end on real infrastructure: leave empty until registry push, Jenkins flow, and cluster deploy evidence exist.')
$content.Add('- Known accepted gaps: any service intentionally excluded from the first release subset, plus services still blocked by workspace-specific Testcontainers issues.')

[System.IO.File]::WriteAllLines($resolvedOutputPath, $content)
Write-Host "Generated final report notes: $OutputFile"

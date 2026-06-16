param(
    [string]$PlanFile = 'docs/service-mesh-test-plan.md',
    [string]$ResultsFile = 'docs/service-mesh-results.md',
    [string]$KialiFile = 'mesh/kiali-access.md'
)

function Assert-ContainsAll {
    param(
        [string]$FilePath,
        [string[]]$Tokens
    )

    $text = Get-Content $FilePath -Raw
    foreach ($token in $Tokens) {
        if (-not $text.Contains($token)) {
            throw "$FilePath is missing required token $token."
        }
    }
}

Assert-ContainsAll -FilePath $PlanFile -Tokens @(
    'mTLS strict mode',
    'mesh/peer-authentication.yaml',
    'Istio proxy',
    'Retry on HTTP 500',
    'mesh/destination-rule.yaml',
    'mesh/virtual-service-retry.yaml',
    'Allow and deny policy',
    'mesh/authorization-policy.yaml',
    'kubectl exec'
)

Assert-ContainsAll -FilePath $ResultsFile -Tokens @(
    '## Namespace',
    '## mTLS evidence',
    '## Retry evidence',
    '## Authorization evidence',
    '<link to screenshot or command output>',
    '<link to logs or screenshot>',
    '<link to curl output or screenshot>'
)

Assert-ContainsAll -FilePath $KialiFile -Tokens @(
    'kubectl -n istio-system port-forward svc/kiali 20001:20001',
    'http://localhost:20001',
    'target namespace'
)

Write-Host 'Service-mesh plan, results template, and Kiali access notes are aligned with the current mesh scaffold.'

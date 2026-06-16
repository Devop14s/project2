param(
    [string]$OutputFile = 'work/status-report.generated.md',
    [string]$ServiceVerificationFile = 'work/service-verification.generated.md',
    [string]$FinalReportNotesFile = 'work/final-report-notes.generated.md',
    [string]$HostCapabilitiesFile = 'work/host-capabilities.generated.md',
    [switch]$SkipCommandChecks
)

$scriptArgs = @(
    '-ExecutionPolicy', 'Bypass',
    '-File', 'scripts\report-status.ps1',
    '-OutputFile', $OutputFile,
    '-ServiceVerificationFile', $ServiceVerificationFile,
    '-FinalReportNotesFile', $FinalReportNotesFile,
    '-HostCapabilitiesFile', $HostCapabilitiesFile
)

if ($SkipCommandChecks) {
    $scriptArgs += '-SkipCommandChecks'
}

& powershell @scriptArgs
exit $LASTEXITCODE

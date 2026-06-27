$ports = @(
  @{ Name = "k3s-6443"; Protocol = "TCP"; Port = 6443 },
  @{ Name = "k3s-8472"; Protocol = "UDP"; Port = 8472 },
  @{ Name = "k3s-10250"; Protocol = "TCP"; Port = 10250 }
)

foreach ($entry in $ports) {
  $existing = Get-NetFirewallRule -DisplayName $entry.Name -ErrorAction SilentlyContinue
  if (-not $existing) {
    New-NetFirewallRule `
      -DisplayName $entry.Name `
      -Direction Inbound `
      -Protocol $entry.Protocol `
      -LocalPort $entry.Port `
      -Action Allow | Out-Null
    Write-Host "Created rule $($entry.Name)"
  } else {
    Write-Host "Rule already exists: $($entry.Name)"
  }
}

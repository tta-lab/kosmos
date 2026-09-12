$ErrorActionPreference = 'Stop'
$name = 'Kosmos-Public-HTTPS'
$creator = '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}'

if (Get-NetFirewallHyperVRule -Name $name -ErrorAction SilentlyContinue) {
    Set-NetFirewallHyperVRule -Name $name -Enabled True -Direction Inbound -Action Allow -Protocol TCP -LocalPorts 27443
} else {
    New-NetFirewallHyperVRule -Name $name -DisplayName 'Kosmos public IPv6 HTTPS' -Direction Inbound -VMCreatorId $creator -Protocol TCP -LocalPorts 27443 -Action Allow | Out-Null
}
Get-NetFirewallHyperVRule -PolicyStore ActiveStore -Name $name |
    Select-Object Name, Enabled, Action, LocalPorts

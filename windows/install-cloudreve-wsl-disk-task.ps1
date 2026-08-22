[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw 'Run this installer from an elevated Windows PowerShell.'
}

$taskName = 'Kosmos-Cloudreve-WSL-Disk'
$source = Join-Path $PSScriptRoot 'cloudreve-wsl-disk.ps1'
if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
  throw "Missing task runtime script: $source"
}

$destinationDirectory = Join-Path $env:LOCALAPPDATA 'Kosmos'
$destination = Join-Path $destinationDirectory 'cloudreve-wsl-disk.ps1'
New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
Copy-Item -LiteralPath $source -Destination $destination -Force
Unblock-File -LiteralPath $destination -ErrorAction SilentlyContinue

$userId = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$action = New-ScheduledTaskAction `
  -Execute (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$destination`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $userId
$taskPrincipal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet `
  -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries `
  -StartWhenAvailable `
  -ExecutionTimeLimit ([TimeSpan]::Zero) `
  -RestartCount 3 `
  -RestartInterval ([TimeSpan]::FromMinutes(1)) `
  -MultipleInstances IgnoreNew
$task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $taskPrincipal -Settings $settings

Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null
Start-ScheduledTask -TaskName $taskName
Start-Sleep -Seconds 2
if ((Get-ScheduledTask -TaskName $taskName).State -ne 'Running') {
  throw "Scheduled task $taskName did not remain running. Check $destinationDirectory\cloudreve-wsl-disk.log."
}

Write-Output "Installed and started $taskName."

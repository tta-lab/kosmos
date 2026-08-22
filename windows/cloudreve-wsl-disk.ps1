[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DiskNumber = 0
$ExpectedDiskSize = [uint64]1920383410176
$FilesystemUuid = '441ba8bb-d21b-40e4-a921-ef5553e07ff3'
$Distro = 'NixOS'
$Wsl = Join-Path $env:SystemRoot 'System32\wsl.exe'
$LogPath = Join-Path $PSScriptRoot 'cloudreve-wsl-disk.log'

function Write-TaskLog([string]$Message) {
  "$(Get-Date -Format o) $Message" | Add-Content -LiteralPath $LogPath
}

function Test-CloudreveDiskAttached {
  & $Wsl -d $Distro --exec /run/current-system/sw/bin/blkid -U $FilesystemUuid | Out-Null
  return $LASTEXITCODE -eq 0
}

function Assert-ExpectedDisk {
  $disk = Get-Disk -Number $DiskNumber
  if ($disk.Size -ne $ExpectedDiskSize) {
    throw "PHYSICALDRIVE$DiskNumber has unexpected size $($disk.Size). Refusing to use it."
  }

  $partitions = @(Get-Partition -DiskNumber $DiskNumber)
  if ($partitions.Count -ne 1 -or $partitions[0].PartitionNumber -ne 1 -or [bool]$partitions[0].DriveLetter) {
    throw "PHYSICALDRIVE$DiskNumber is not the expected single non-Windows data partition."
  }

  return $disk
}

function Attach-CloudreveDisk {
  if (Test-CloudreveDiskAttached) {
    Write-TaskLog 'Cloudreve disk is already attached to WSL.'
    return
  }

  $disk = Assert-ExpectedDisk
  if (-not $disk.IsOffline) {
    Write-TaskLog 'Taking the verified Micron data disk offline in Windows.'
    Set-Disk -Number $DiskNumber -IsOffline $true
  }

  Write-TaskLog 'Attaching the Micron data disk bare to WSL.'
  & $Wsl --mount "\\.\PHYSICALDRIVE$DiskNumber" --bare
  if ($LASTEXITCODE -ne 0) {
    throw "wsl.exe --mount failed with exit code $LASTEXITCODE."
  }

  $deadline = [DateTime]::UtcNow.AddSeconds(30)
  while (-not (Test-CloudreveDiskAttached)) {
    if ([DateTime]::UtcNow -ge $deadline) {
      throw "WSL did not expose filesystem UUID $FilesystemUuid after attaching PHYSICALDRIVE$DiskNumber."
    }
    Start-Sleep -Seconds 1
  }

  Write-TaskLog 'Micron data disk is attached to WSL.'
}

$principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw 'This task must run elevated so Windows can take PHYSICALDRIVE0 offline and attach it to WSL.'
}

while ($true) {
  try {
    Attach-CloudreveDisk
    Write-TaskLog 'Starting the persistent NixOS WSL process.'
    & $Wsl -d $Distro --exec /run/current-system/sw/bin/sleep infinity
    Write-TaskLog "NixOS WSL process exited with code $LASTEXITCODE; retrying in five seconds."
  } catch {
    Write-TaskLog "Cloudreve disk task failed: $($_.Exception.Message)"
    throw
  }

  Start-Sleep -Seconds 5
}

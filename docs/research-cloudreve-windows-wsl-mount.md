# Cloudreve Windows-to-WSL storage recovery

Research date: 2026-08-29. This documents the current failed state and the
smallest safe recovery. It does not change the Cloudreve data disk or any
running configuration.

## Finding

Cloudreve's 2 TiB Micron disk is currently **offline in Windows but no longer
attached to WSL**. This is an attachment failure, not evidence of filesystem
corruption:

- WSL has no block device with UUID `441ba8bb-d21b-40e4-a921-ef5553e07ff3`;
  `mnt-kosmos\x2dcloudreve.mount` is inactive and
  `cloudreve-storage.service` repeatedly reports `Can't lookup blockdev` for
  that UUID.
- Windows Disk 0 is the expected healthy
  `Micron_5200_MTFDDAK1T9TDD`, with size `1920383410176`, one data partition,
  and `IsOffline = True`. Offline is expected while WSL owns the disk.
- The Windows-side mechanism is a **Scheduled Task**, not a Windows Service:
  `Kosmos-Cloudreve-WSL-Disk`. At inspection it was `Ready` (not `Running`),
  with its last run on 2026-08-22. Its installed runtime script exactly matches
  [`windows/cloudreve-wsl-disk.ps1`](../windows/cloudreve-wsl-disk.ps1).

The task validates Disk 0's size and partition layout, takes it offline when
needed, runs `wsl.exe --mount \\.\PHYSICALDRIVE0 --bare`, waits for the UUID
in the `NixOS` distribution, then holds that distribution open with `sleep
infinity`. The NixOS service then mounts the ext4 filesystem at
`/mnt/kosmos-cloudreve` and creates its two hostPath directories.

Microsoft documents that `wsl --mount <disk> --bare` only attaches the block
device: Linux must mount it itself; elevation is required and Windows cannot
still be using the disk. [WSL disk mounting](https://learn.microsoft.com/en-us/windows/wsl/wsl2-mount-disk#attaching-the-disk-without-mounting-it)
· [Set-Disk `-IsOffline`](https://learn.microsoft.com/en-us/powershell/module/storage/set-disk?view=windowsserver2025-ps#-isoffline).

## Restore

In an **elevated Windows PowerShell**, inspect then restart the stopped task:

```powershell
$name = 'Kosmos-Cloudreve-WSL-Disk'
Get-ScheduledTask -TaskName $name
Get-ScheduledTaskInfo -TaskName $name
Get-Content "$env:LOCALAPPDATA\Kosmos\cloudreve-wsl-disk.log" -Tail 100
Start-ScheduledTask -TaskName $name
Get-ScheduledTask -TaskName $name
Get-Content "$env:LOCALAPPDATA\Kosmos\cloudreve-wsl-disk.log" -Tail 100 -Wait
```

The expected new log entries are *Attaching the Micron data disk bare to WSL*,
*Micron data disk is attached to WSL*, and *Starting the persistent NixOS WSL
process*. Do not make Disk 0 online in Windows, and do not use `wsl --unmount`
or `wsl --shutdown` while this storage is in use; shutting down WSL terminates
the WSL instance, so its attached disks must be attached again. [WSL shutdown
reference](https://learn.microsoft.com/en-us/windows/wsl/basic-commands#shutdown).

Then verify in WSL (the storage service will retry the Linux mount by itself):

```bash
lsblk -f
blkid -U 441ba8bb-d21b-40e4-a921-ef5553e07ff3
findmnt /mnt/kosmos-cloudreve
systemctl status cloudreve-storage.service --no-pager
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get pods,pvc -n cloudreve -o wide
```

Only if the task records a new error should recovery branch from its log. In
particular, do not manually attach a guessed disk: the task deliberately
refuses a disk whose size or partition layout differs from the Micron disk.

## K3s interaction and activation coupling

The current static PVs point to
`/mnt/kosmos-cloudreve/cloudreve/{data,postgres}` and set
`hostPath.type: Directory`. That is the safe choice: Kubernetes requires the
directory to already exist, whereas `DirectoryOrCreate` would create it on the
WSL root filesystem when the data disk is absent. [Kubernetes hostPath volume
types](https://kubernetes.io/docs/concepts/storage/volumes/#hostpath-volume-types).
The observed `FailedMount` events therefore protect the retained data; a
`Bound` PVC does not prove that the node path is mountable.

The switch hang is a separate, avoidable systemd coupling:

- `cloudreve-secret-sync.service` is a `multi-user.target` `Type=oneshot`,
  `Restart=on-failure` unit with an infinite start timeout.
- [`scripts/sync-cloudreve-secret`](../scripts/sync-cloudreve-secret) always
  calls `kubectl rollout status deployment/cloudreve --timeout=300s` whenever
  the Deployment exists, including when the Secret is unchanged.
- When the hostPath is unavailable, kubelet correctly cannot start Cloudreve;
  the 300-second wait fails, systemd retries five seconds later, and activation
  continues waiting on the unit.

Implemented: the systemd sync now ends after applying or patching the
Kubernetes Secret/Deployment, while `just cloudreve-deploy` performs the
explicit rollout-readiness check. Kubernetes can therefore reconcile a
temporarily unavailable PV without blocking a normal `nh os switch`; the
storage guard above remains unchanged. The systemd reconciler is `Type=simple`,
so an exceptional PostgreSQL password-rotation retry is asynchronous as well.

Password rotation is a distinct case: the current script intentionally waits
for a ready PostgreSQL Pod before executing `ALTER USER`, so it does not publish
a new application password before the existing database accepts it. Removing
that wait needs an explicit rotation design; it should not be silently removed
along with the unconditional deployment-health wait.

## Repository sources

- [`windows/cloudreve-wsl-disk.ps1`](../windows/cloudreve-wsl-disk.ps1) and
  [`windows/install-cloudreve-wsl-disk-task.ps1`](../windows/install-cloudreve-wsl-disk-task.ps1)
  — task safety checks, mount command, and lifecycle.
- [`modules/wsl/cloudreve-storage.nix`](../modules/wsl/cloudreve-storage.nix)
  — UUID-checked mount and directory preparation.
- [`tanka/lib/cloudreve-storage.libsonnet`](../tanka/lib/cloudreve-storage.libsonnet)
  — static hostPath PVs.
- [`modules/wsl/secrets.nix`](../modules/wsl/secrets.nix) and
  [`scripts/sync-cloudreve-secret`](../scripts/sync-cloudreve-secret) — the
  systemd and rollout behavior.

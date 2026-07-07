# WSL Data Disk Notes

Status: deferred. This disk is not part of the current DevOps MVP gate.

## Current Findings

Windows shows two physical disks:

```text
Disk 0  Micron_5200_MTFDDAK1T9TDD  SATA  ~1.92TB
Disk 1  SOLIDIGM SSDPFKNU010TZ     NVMe  ~1TB, Windows C:
```

The large Micron disk has one Windows-unknown partition of about 1788GiB. It was
previously visible inside Kosmos WSL as:

```text
/dev/sde  ext4  UUID=bf1ab97f-1d98-4977-89ed-58a8d0098e6c
```

After deleting the old Podman machine from Windows/Podman Desktop, that block
device disappeared from the current WSL instance. Current Kosmos WSL sees only
its root disk:

```text
/dev/sdd  ext4  UUID=b7e722a7-f73f-42b0-83d0-758790ff4aa3  mounted at /
```

## Old Disk Contents

Before the device disappeared, read-only `debugfs` inspection showed the disk was
not empty. It looked like an old Podman Desktop Fedora machine root filesystem,
not an old Arch Linux install:

```text
/etc/fedora-release
/var/lib/dnf
/var/lib/rpm
/var/lib/containers
/home/user/.ansible
/home/user/playbook.yaml
```

The playbook content was:

```yaml
---
- name: Create a symbolic link for registries.conf from host to VM
  hosts: localhost
  become: true
  tasks:
    - name: Create symbolic link with sudo from the host
      command: sudo ln -s /mnt/c/Users/white/.config/containers/registries.conf /etc/containers/registries.conf.d/999-podman-desktop-registries-from-host.conf
```

Container storage looked effectively empty:

```text
/var/lib/containers/storage/volumes            empty
/var/lib/containers/storage/overlay-images     only images.lock
/var/lib/containers/storage/overlay-containers only containers.lock
```

So the disk appears safe to reuse once Neil explicitly confirms clearing it, but
it should not be treated as blank by default.

## WSL Mount Model

Microsoft's supported path for Linux/ext4 disks is `wsl --mount` from an
elevated Windows shell. Important constraints:

- `wsl --mount` requires Administrator privileges.
- WSL attaches whole physical disks, not just a single partition.
- WSL cannot attach the Windows system disk.
- The Windows-side attach is not a normal NixOS mount and is not reliably
  persistent across Windows or WSL restarts.

That means the clean model is two-layer:

```text
Windows layer:
  wsl --mount \\.\PHYSICALDRIVE0 --bare

NixOS WSL layer:
  mount /dev/disk/by-uuid/<uuid> at /mnt/nuc-data
```

For long-running use, the Windows layer should be automated with Task Scheduler
or another explicit Windows bootstrap step. Nix can only manage the Linux mount
after the block device is visible inside WSL.

## Deferred Path

If this becomes important later:

1. Confirm the Micron disk is still the intended data disk.
2. Attach it from elevated PowerShell:

   ```powershell
   wsl --mount \\.\PHYSICALDRIVE0 --bare
   ```

3. Confirm the device from WSL:

   ```bash
   lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINTS,MODEL,SERIAL
   sudo blkid
   ```

4. If Neil confirms the old Podman machine data can be discarded, format it as a
   clean data disk:

   ```bash
   sudo mkfs.ext4 -L nuc-data /dev/<device>
   sudo blkid /dev/<device>
   ```

5. Enable the Nix mount using the new UUID:

   ```nix
   kosmos.wsl.dataDisk = {
     enable = true;
     device = "/dev/disk/by-uuid/<new-uuid>";
     mountPoint = "/mnt/nuc-data";
   };
   ```

6. Only after the disk is stable, decide whether Forgejo backup replication
   should target `/mnt/nuc-data/forgejo-backups`.


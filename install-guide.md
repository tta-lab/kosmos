# NixOS Install Guide for Intel NUC (kosmos)

## Prerequisites

- [NixOS minimal ISO](https://nixos.org/download/) (25.05 or latest stable)
- USB drive (≥2GB) to flash the ISO
- Intel NUC (12th Gen i5-1240P) with NVMe drive
- Mac on same LAN with clash verge proxy running (port 7890)
- USB keyboard and monitor (for initial setup)

## 1. Create Bootable USB

On your Mac:

```bash
# Find your USB device (e.g., /dev/disk2)
diskutil list

# Unmount and flash
diskutil unmountDisk /dev/disk2
sudo dd if=/path/to/nixos-minimal-25.05-x86_64-linux.iso of=/dev/disk2 bs=4m status=progress
diskutil eject /dev/disk2
```

## 2. Boot from USB

1. Insert USB into NUC
2. Power on, press F10 (or appropriate key) for boot menu
3. Select USB drive
4. NixOS boots to a shell — you should see `nixos@nixos:~$`

## 3. Verify Disk & Network

```bash
# Identify NVMe device — should be /dev/nvme0n1
lsblk

# Check network interfaces
ip link

# If DHCP works, get an IP
ip addr
```

If no DHCP, the proxy config won't work yet — but that's fine, we're offline for install.

## 4. Copy Config Files

From your Mac:

```bash
scp disko-config.nix configuration.nix nixos@<nuc-ip>:
```

Or if no network yet, recreate the files manually.

## 5. Partition with disko

```bash
# Copy the disko config from the repo
# (On Mac, scp the files to the NUC, or type them manually)
nix-shell -p disko
disko --mode disko disko-config.nix
```

> **Note:** Replace `disko-config.nix` device path if your NVMe is not `/dev/nvme0n1`.

## 6. Generate Hardware Config

```bash
nixos-generate-config --root /mnt
```

## 7. Copy Configuration

```bash
# Copy our configs
cp -r configuration.nix disko-config.nix modules/ /mnt/etc/nixos/

# Merge any hardware-specific lines from the generated config
# (especially filesystem UUIDs, kernel modules)
cat /mnt/etc/nixos/hardware-configuration.nix
```

Edit `/mnt/etc/nixos/configuration.nix` to:
- Replace `<mac-ip>` with the actual LAN IP of your Mac running clash verge
- Add your SSH public key(s) to `users.users.neil.openssh.authorizedKeys.keys`

## 8. Install

```bash
nixos-install --root /mnt

# Set root password when prompted
# User 'neil' has initial password 'changeme' — change on first login
```

## 9. Reboot

```bash
reboot
```

Remove the USB drive when prompted.

## 10. Connect via SSH

From your Mac:

```bash
# Find the NUC's IP on your LAN (check router or use nmap)
nmap -sn 192.168.1.0/24

# SSH in (initial password: changeme)
ssh neil@<nuc-ip>

# Change password immediately
passwd
```

## 11. Verify Proxy

```bash
# Test internet through proxy
curl -v https://google.com

# If it fails, check the proxy address in /etc/nixos/configuration.nix
# and rebuild:
sudo nixos-rebuild switch
```

## 12. Next Steps

Once the NUC is online and SSH-accessible, proceed to Phase 2 — flake migration:

```bash
cd /etc/nixos
sudo -i
git clone <repo-url> .
nixos-rebuild switch --flake .#kosmos
```

## 13. Flake Rebuild (Phase 2)

After pushing the flake setup to your repo:

```bash
# On the NUC
cd /etc/nixos
sudo -i

# Clone or pull the latest config
# (if fresh: clone the repo)
git clone <repo-url> /etc/nixos

# Rebuild using nh (installed via packages)
nh os switch . -H kosmos

# Or using nixos-rebuild directly
nixos-rebuild switch --flake .#kosmos
```

### Verification

```bash
# Check services
systemctl status sshd
systemctl status systemd-networkd

# Test internet
curl https://google.com

# Check shell
fish --version

# Check tools
hx --version
tmux --version
podman --version
mihomo --version

# Run a container
podman run hello-world
```

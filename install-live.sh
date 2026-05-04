#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/Corentinrhr/nixos-conf"
FLAKE_HOST="nixos"

echo "=== NixOS 25.11 Installation ==="

[[ "$(id -u)" -ne 0 ]] && { echo "Run as root."; exit 1; }
[[ ! -d /sys/firmware/efi/efivars ]] && { echo "Not booted in UEFI mode."; exit 1; }

echo "[1/9] UEFI mode confirmed."
echo
echo "Available disks:"
lsblk -d -p -o NAME,SIZE,MODEL | grep -E "^/dev/"
echo
read -r -p "Target disk for NixOS (e.g. /dev/nvme0n1): " DISK
[[ ! -b "$DISK" ]] && { echo "Invalid device: $DISK"; exit 1; }

# Detect Windows EFI partition
WIN_EFI=""
for part in $(blkid -t TYPE=vfat -o device); do
  mkdir -p /tmp/check_efi
  if mount -o ro "$part" /tmp/check_efi 2>/dev/null; then
    if [[ -d "/tmp/check_efi/EFI/Microsoft" ]]; then
      WIN_EFI="$part"
      umount /tmp/check_efi
      break
    fi
    umount /tmp/check_efi
  fi
done
rmdir /tmp/check_efi 2>/dev/null || true

echo
[[ -n "$WIN_EFI" ]] && echo "Windows EFI detected: $WIN_EFI" || echo "No Windows EFI found."
echo
echo "!!! ALL DATA ON $DISK WILL BE ERASED !!!"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS "$DISK" || true
echo
read -r -p "Type YES to continue: " CONFIRM
[[ "$CONFIRM" != "YES" ]] && { echo "Aborted."; exit 1; }

echo "[2/9] Partitioning $DISK..."
wipefs -af "$DISK"
sgdisk --zap-all "$DISK"
partprobe "$DISK"
sleep 2

[[ "$DISK" =~ [0-9]$ ]] && PART_SUFFIX="p" || PART_SUFFIX=""
PART_EFI="${DISK}${PART_SUFFIX}1"
PART_ROOT="${DISK}${PART_SUFFIX}2"

parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart ESP fat32 1MiB 1025MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary btrfs 1025MiB 100%
partprobe "$DISK"
sleep 2

echo "[3/9] Formatting..."
mkfs.fat -F 32 -n EFI "$PART_EFI"
mkfs.btrfs -f -L nixos "$PART_ROOT"

echo "[4/9] Btrfs subvolumes..."
mount "$PART_ROOT" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
umount /mnt

echo "[5/9] Mounting..."
BTRFS_OPTS="compress=zstd:3,noatime,ssd,discard=async"
mount -o "subvol=@,${BTRFS_OPTS}" "$PART_ROOT" /mnt
mkdir -p /mnt/{home,nix,boot}
mount -o "subvol=@home,${BTRFS_OPTS}" "$PART_ROOT" /mnt/home
mount -o "subvol=@nix,${BTRFS_OPTS}" "$PART_ROOT" /mnt/nix
mount "$PART_EFI" /mnt/boot

echo "[6/9] Generating hardware config..."
nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix /root/hardware-configuration.nix
rm -rf /mnt/etc/nixos

echo "[7/9] Cloning config repository..."
git clone "$REPO_URL" /mnt/etc/nixos
cp /root/hardware-configuration.nix /mnt/etc/nixos/hardware-configuration.nix

echo "[8/9] Copying Windows EFI files..."
if [[ -n "$WIN_EFI" ]]; then
  mkdir -p /mnt/windows-efi
  if mount "$WIN_EFI" /mnt/windows-efi; then
    mkdir -p /mnt/boot/EFI
    [[ -d /mnt/windows-efi/EFI/Microsoft ]] && \
      cp -r /mnt/windows-efi/EFI/Microsoft /mnt/boot/EFI/ || \
      echo "Warning: EFI/Microsoft not found on $WIN_EFI"
    umount /mnt/windows-efi
  fi
  rmdir /mnt/windows-efi || true

  # Print Windows EFI UUID for use in boot.nix extraEntries
  echo
  echo "=== Windows EFI UUID (use in boot.nix if useOSProber fails) ==="
  blkid "$WIN_EFI" -s UUID -o value
fi

echo "[9/9] Setting password and installing..."
HASH="$(nix --extra-experimental-features 'nix-command flakes' \
  run nixpkgs#mkpasswd -- -m sha-512)"
sed -i "s|hashedPassword = \".*\";|hashedPassword = \"${HASH}\";|" \
  /mnt/etc/nixos/configuration.nix

cd /mnt/etc/nixos
git add -A

NIX_CONFIG="experimental-features = nix-command flakes
accept-flake-config = true" \
nixos-install --flake "/mnt/etc/nixos#${FLAKE_HOST}" --no-root-passwd

echo
echo "=== Installation complete ==="
echo "IMPORTANT: Keep Secure Boot DISABLED for first boot."
echo "After first login, run: sudo /etc/nixos/post-boot-secureboot.sh"
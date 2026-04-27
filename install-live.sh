#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/Corentinrhr/nixos-conf"
FLAKE_HOST="nixos"

echo "=== Starting NixOS installation ==="

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: please run this script as root."
  exit 1
fi

if ! test -d /sys/firmware/efi/efivars; then
  echo "Error: system was not booted in UEFI mode."
  exit 1
fi

echo "[1/10] UEFI mode detected."

echo
echo "Available disks:"
lsblk -d -p -o NAME,SIZE,MODEL | grep -E "^/dev/"
echo
read -r -p "Enter the target disk path for NixOS (e.g., /dev/nvme0n1 or /dev/sda): " DISK

if [ ! -b "$DISK" ]; then
  echo "Error: $DISK is not a valid block device."
  exit 1
fi

WIN_EFI=""
echo
echo "Detecting Windows EFI partition..."
# Parcourt toutes les partitions vfat (FAT32) pour trouver le bootloader Microsoft
for part in $(blkid -t TYPE=vfat -o device); do
  mkdir -p /tmp/check_efi
  if mount -o ro "$part" /tmp/check_efi 2>/dev/null; then
    if [ -d "/tmp/check_efi/EFI/Microsoft" ]; then
      WIN_EFI="$part"
      umount /tmp/check_efi
      break
    fi
    umount /tmp/check_efi
  fi
done
rmdir /tmp/check_efi 2>/dev/null || true

if [ -n "$WIN_EFI" ]; then
  echo "-> Windows EFI partition automatically detected on: $WIN_EFI"
else
  echo "-> No Windows EFI partition detected. Skipping Windows boot entry copy."
fi

echo
echo "!!! WARNING: DESTRUCTIVE ACTION !!!"
echo "Target disk for NixOS: ${DISK}"
if [ -n "$WIN_EFI" ]; then
  echo "Windows EFI partition: ${WIN_EFI}"
fi
echo
echo "Target disk layout:"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL "${DISK}" || true
echo

if [ -n "$WIN_EFI" ]; then
  echo "Windows EFI partition layout:"
  lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL "${WIN_EFI}" || true
  echo
fi

echo "ALL DATA ON ${DISK} WILL BE PERMANENTLY ERASED."
if [ -n "$WIN_EFI" ]; then
  echo "Windows will not be erased, but its EFI entry will be copied into the NixOS EFI partition."
fi
echo

read -r -p "Type 'YES' in all caps to continue: " CONFIRMATION
if [ "${CONFIRMATION}" != "YES" ]; then
  echo "Aborting. No changes were made."
  exit 1
fi

echo "[2/10] Wiping target disk..."
wipefs -af "${DISK}"
sgdisk --zap-all "${DISK}"
partprobe "${DISK}"
sleep 2 # Laisse le temps au kernel d'actualiser la table des partitions

# Détermination du suffixe de partition (ex: /dev/sda -> /dev/sda1, mais /dev/nvme0n1 -> /dev/nvme0n1p1)
if [[ "$DISK" =~ [0-9]$ ]]; then
  PART_SUFFIX="p"
else
  PART_SUFFIX=""
fi

PART_EFI="${DISK}${PART_SUFFIX}1"
PART_ROOT="${DISK}${PART_SUFFIX}2"

echo "[3/10] Creating partitions..."
parted -s "${DISK}" mklabel gpt
parted -s "${DISK}" mkpart ESP fat32 1MiB 1025MiB
parted -s "${DISK}" set 1 esp on
parted -s "${DISK}" mkpart primary btrfs 1025MiB 100%
partprobe "${DISK}"
sleep 2

echo "[4/10] Formatting filesystems..."
mkfs.fat -F 32 -n EFI "${PART_EFI}"
mkfs.btrfs -f -L nixos "${PART_ROOT}"

echo "[5/10] Creating Btrfs subvolumes..."
mount "${PART_ROOT}" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
umount /mnt

echo "[6/10] Mounting target filesystem..."
mount -o subvol=@,compress=zstd,noatime,ssd,discard=async "${PART_ROOT}" /mnt
mkdir -p /mnt/{home,nix,boot}
mount -o subvol=@home,compress=zstd,noatime,ssd,discard=async "${PART_ROOT}" /mnt/home
mount -o subvol=@nix,compress=zstd,noatime,ssd,discard=async "${PART_ROOT}" /mnt/nix
mount "${PART_EFI}" /mnt/boot

echo "[7/10] Generating hardware configuration..."
nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix /root/hardware-configuration.nix
rm -rf /mnt/etc/nixos

echo "[8/10] Cloning configuration repository..."
git clone "${REPO_URL}" /mnt/etc/nixos
cp /root/hardware-configuration.nix /mnt/etc/nixos/hardware-configuration.nix

echo "[9/10] Copying Windows EFI files..."
if [ -n "$WIN_EFI" ]; then
  mkdir -p /mnt/windows-efi
  if mount "${WIN_EFI}" /mnt/windows-efi; then
    mkdir -p /mnt/boot/EFI
    if [ -d /mnt/windows-efi/EFI/Microsoft ]; then
      cp -r /mnt/windows-efi/EFI/Microsoft /mnt/boot/EFI/
    else
      echo "Warning: Windows EFI files were not found on ${WIN_EFI}."
    fi
    umount /mnt/windows-efi
  else
    echo "Warning: could not mount ${WIN_EFI}. Skipping Windows EFI copy."
  fi
  rmdir /mnt/windows-efi || true
else
  echo "No Windows EFI partition configured or found. Skipping."
fi

echo "[10/10] Generating password hash..."
HASH="$(nix --extra-experimental-features "nix-command flakes" run nixpkgs#mkpasswd -- -m sha-512)"
sed -i "s|hashedPassword = \".*\";|hashedPassword = \"${HASH}\";|" /mnt/etc/nixos/configuration.nix

cd /mnt/etc/nixos
git add -A

echo "Installing NixOS..."
NIX_CONFIG=$'experimental-features = nix-command flakes\naccept-flake-config = true' \
nixos-install --flake "/mnt/etc/nixos#${FLAKE_HOST}" --no-root-passwd

echo
echo "=== Installation completed successfully ==="
echo "Important:"
echo "- Secure Boot must remain DISABLED for the first boot."
echo "- The initial install uses systemd-boot only."
echo "- Run post-boot-secureboot.sh after the first successful login."
#!/usr/bin/env bash
set -euo pipefail

DISK="/dev/nvme0n1"
WIN_EFI="/dev/nvme1n1p4"
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
echo "!!! WARNING: DESTRUCTIVE ACTION !!!"
echo "Target disk for NixOS: ${DISK}"
echo "Windows EFI partition: ${WIN_EFI}"
echo
echo "Target disk layout:"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL "${DISK}" || true
echo
echo "Windows EFI partition:"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL "${WIN_EFI}" || true
echo
echo "ALL DATA ON ${DISK} WILL BE PERMANENTLY ERASED."
echo "Windows will not be erased, but its EFI entry may be copied into the NixOS EFI partition."
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

echo "[3/10] Creating partitions..."
parted -s "${DISK}" mklabel gpt
parted -s "${DISK}" mkpart ESP fat32 1MiB 1025MiB
parted -s "${DISK}" set 1 esp on
parted -s "${DISK}" mkpart primary btrfs 1025MiB 100%
partprobe "${DISK}"

echo "[4/10] Formatting filesystems..."
mkfs.fat -F 32 -n EFI "${DISK}p1"
mkfs.btrfs -f -L nixos "${DISK}p2"

echo "[5/10] Creating Btrfs subvolumes..."
mount "${DISK}p2" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
umount /mnt

echo "[6/10] Mounting target filesystem..."
mount -o subvol=@,compress=zstd,noatime,ssd,discard=async "${DISK}p2" /mnt
mkdir -p /mnt/{home,nix,boot}
mount -o subvol=@home,compress=zstd,noatime,ssd,discard=async "${DISK}p2" /mnt/home
mount -o subvol=@nix,compress=zstd,noatime,ssd,discard=async "${DISK}p2" /mnt/nix
mount "${DISK}p1" /mnt/boot

echo "[7/10] Generating hardware configuration..."
nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix /root/hardware-configuration.nix
rm -rf /mnt/etc/nixos

echo "[8/10] Cloning configuration repository..."
git clone "${REPO_URL}" /mnt/etc/nixos
cp /root/hardware-configuration.nix /mnt/etc/nixos/hardware-configuration.nix

echo "[9/10] Copying Windows EFI files..."
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
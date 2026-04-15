#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# CONFIGURATION
# ==========================================
DISK="/dev/nvme0n1"
WIN_EFI="/dev/nvme1n1p4"
REPO_URL="https://github.com/Corentinrhr/nixos-conf"
FLAKE_HOST="nixos"

echo "=== Starting NixOS installation ==="

# ==========================================
# 1. SAFETY CHECKS
# ==========================================
if ! test -d /sys/firmware/efi/efivars; then
  echo "Error: system was not booted in UEFI mode."
  exit 1
fi

echo "[1/10] UEFI mode detected."

# ==========================================
# 2. CONFIRMATION PROMPT
# ==========================================
echo ""
echo "!!! WARNING: DESTRUCTIVE ACTION !!!"
echo "Target disk for NixOS: ${DISK}"
echo "Windows EFI partition: ${WIN_EFI}"
echo ""
echo "Current layout of the target disk (${DISK}):"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL "${DISK}" || true
echo ""
echo "ALL DATA ON ${DISK} WILL BE PERMANENTLY ERASED."
echo "Your Windows disk will not be wiped, but its EFI bootloader will be copied."
echo ""

read -p "Are you absolutely sure you want to proceed? Type 'YES' in all caps to continue: " CONFIRMATION

if [ "$CONFIRMATION" != "YES" ]; then
  echo "Aborting installation. No changes were made."
  exit 1
fi

# ==========================================
# 3. WIPE TARGET DISK
# ==========================================
echo "[3/10] Wiping ${DISK}..."
wipefs -af "${DISK}"
sgdisk --zap-all "${DISK}"
partprobe "${DISK}"

# ==========================================
# 4. PARTITIONING
# ==========================================
echo "[4/10] Creating GPT partitions..."
parted -s "${DISK}" mklabel gpt
parted -s "${DISK}" mkpart ESP fat32 1MiB 1025MiB
parted -s "${DISK}" set 1 esp on
parted -s "${DISK}" mkpart primary btrfs 1025MiB 100%
partprobe "${DISK}"

# ==========================================
# 5. FORMAT FILESYSTEMS
# ==========================================
echo "[5/10] Formatting partitions..."
mkfs.fat -F 32 -n EFI "${DISK}p1"
mkfs.btrfs -f -L nixos "${DISK}p2"

# ==========================================
# 6. CREATE BTRFS SUBVOLUMES
# ==========================================
echo "[6/10] Creating BTRFS subvolumes..."
mount "${DISK}p2" /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix

umount /mnt

echo "[6/10] Mounting BTRFS subvolumes..."
mount -o subvol=@,compress=zstd,noatime,ssd,discard=async "${DISK}p2" /mnt
mkdir -p /mnt/{home,nix,boot}
mount -o subvol=@home,compress=zstd,noatime,ssd,discard=async "${DISK}p2" /mnt/home
mount -o subvol=@nix,compress=zstd,noatime,ssd,discard=async "${DISK}p2" /mnt/nix
mount "${DISK}p1" /mnt/boot

# ==========================================
# 7. GENERATE HARDWARE CONFIG + CLONE REPO
# ==========================================
echo "[7/10] Generating hardware configuration..."
nixos-generate-config --root /mnt

cp /mnt/etc/nixos/hardware-configuration.nix /root/hardware-configuration.nix
rm -rf /mnt/etc/nixos

echo "[7/10] Cloning configuration repository..."
git clone "${REPO_URL}" /mnt/etc/nixos
cp /root/hardware-configuration.nix /mnt/etc/nixos/hardware-configuration.nix

# ==========================================
# 8. COPY WINDOWS EFI ENTRY
# ==========================================
echo "[8/10] Copying Windows EFI files into the NixOS EFI partition..."
mkdir -p /mnt/windows-efi
mount "${WIN_EFI}" /mnt/windows-efi

mkdir -p /mnt/boot/EFI
if [ -d /mnt/windows-efi/EFI/Microsoft ]; then
  cp -r /mnt/windows-efi/EFI/Microsoft /mnt/boot/EFI/
else
  echo "Warning: Windows EFI files were not found on ${WIN_EFI}."
fi

umount /mnt/windows-efi
rmdir /mnt/windows-efi

# ==========================================
# 9. SET USER PASSWORD HASH
# ==========================================
echo "[9/10] Generating password hash for your main user..."
HASH="$(nix run nixpkgs#mkpasswd -- -m sha-512)"

echo "Updating hashedPassword in modules/configuration.nix..."
sed -i "s|hashedPassword = ".*";|hashedPassword = "${HASH}";|" /mnt/etc/nixos/modules/configuration.nix

# ==========================================
# 10. INSTALL NIXOS
# ==========================================
echo "[10/10] Installing NixOS..."
nixos-install --flake "/mnt/etc/nixos#${FLAKE_HOST}"

echo
echo "=== Installation completed successfully ==="
echo "Important:"
echo "- Keep Secure Boot DISABLED for the first boot."
echo "- Reboot into your new NixOS installation."
echo "- Run the post-boot script after logging in."

#!/usr/bin/env bash
# NixOS 25.11 — Dual-boot install script

set -euo pipefail

REPO_URL="https://github.com/Corentinrhr/nixos-conf"
FLAKE_HOST="nixos"

# ── colour helpers ─────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

echo "=== NixOS 25.11 Installation ==="
echo

# ── privilege / UEFI ──────────────────────────────────────────────────────────
[[ "$(id -u)" -ne 0 ]]            && err "Run this script as root."
[[ ! -d /sys/firmware/efi/efivars ]] && err "Not booted in UEFI mode."
info "UEFI mode confirmed."

# ── disk selection ────────────────────────────────────────────────────────────
echo
echo "Available disks:"
lsblk -d -p -o NAME,SIZE,MODEL | grep -E "^/dev/"
echo
read -r -p "Target disk for NixOS (e.g. /dev/nvme0n1): " DISK
[[ ! -b "$DISK" ]] && err "Invalid block device: $DISK"

# Partition suffix: /dev/nvme0n1 -> p1, /dev/sda -> 1
[[ "$DISK" =~ [0-9]$ ]] && PSUF="p" || PSUF=""
PART_EFI="${DISK}${PSUF}1"
PART_ROOT="${DISK}${PSUF}2"

# ── resume detection ──────────────────────────────────────────────────────────
SKIP_FORMAT=false

if blkid "$PART_ROOT" 2>/dev/null | grep -q 'TYPE="btrfs"'; then
  echo
  warn "A Btrfs partition was found on ${PART_ROOT}."
  warn "This disk appears to have been partitioned by a previous run."
  echo
  echo "  [1] Skip partitioning & formatting  (resume from clone step)"
  echo "  [2] Full wipe and start over        (ALL DATA WILL BE LOST)"
  echo
  read -r -p "Choice [1/2]: " RESUME_CHOICE
  case "$RESUME_CHOICE" in
    1) SKIP_FORMAT=true  ; info "Resuming — partitioning will be skipped." ;;
    2) SKIP_FORMAT=false ; warn "Continuing with full wipe." ;;
    *) err "Invalid choice. Aborting." ;;
  esac
fi

# ── Windows EFI detection ─────────────────────────────────────────────────────
WIN_EFI=""
info "Scanning for Windows EFI partition..."
for part in $(blkid -t TYPE=vfat -o device 2>/dev/null); do
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

if [[ -n "$WIN_EFI" ]]; then
  info "Windows EFI partition detected: ${WIN_EFI}"
else
  warn "No Windows EFI partition found — Windows entry will be skipped."
fi

# ── destructive confirmation (only when formatting) ───────────────────────────
if [[ "$SKIP_FORMAT" == "false" ]]; then
  echo
  echo -e "${RED}!!! WARNING: DESTRUCTIVE ACTION !!!${NC}"
  echo "Target disk : ${DISK}"
  [[ -n "$WIN_EFI" ]] && echo "Windows EFI : ${WIN_EFI}  (will NOT be erased)"
  echo
  lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS "${DISK}" 2>/dev/null || true
  echo
  echo "ALL DATA ON ${DISK} WILL BE PERMANENTLY ERASED."
  echo
  read -r -p "Type YES in capitals to confirm: " CONFIRM
  [[ "$CONFIRM" != "YES" ]] && { echo "Aborted. No changes made."; exit 0; }
fi

# ═════════════════════════════════════════════════════════════════════════════
# [1-3] PARTITION + FORMAT + BTRFS SUBVOLUMES
# ═════════════════════════════════════════════════════════════════════════════
if [[ "$SKIP_FORMAT" == "false" ]]; then
  info "[1/9] Wiping ${DISK}..."
  wipefs -af "${DISK}"
  sgdisk --zap-all "${DISK}"
  partprobe "${DISK}"
  sleep 2

  info "[2/9] Partitioning..."
  parted -s "${DISK}" mklabel gpt
  parted -s "${DISK}" mkpart ESP fat32 1MiB 1025MiB
  parted -s "${DISK}" set 1 esp on
  parted -s "${DISK}" mkpart primary btrfs 1025MiB 100%
  partprobe "${DISK}"
  sleep 2

  info "[3a/9] Formatting..."
  mkfs.fat -F 32 -n EFI "${PART_EFI}"
  mkfs.btrfs -f -L nixos "${PART_ROOT}"

  info "[3b/9] Creating Btrfs subvolumes..."
  mount "${PART_ROOT}" /mnt
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@home
  btrfs subvolume create /mnt/@nix
  umount /mnt
else
  info "[1-3/9] Skipped (resume mode)."
fi

# ═════════════════════════════════════════════════════════════════════════════
# [4] MOUNT
# ═════════════════════════════════════════════════════════════════════════════
info "[4/9] Mounting filesystems..."
# Safely unmount if already mounted from a previous failed attempt
mountpoint -q /mnt && umount -R /mnt 2>/dev/null || true

BTRFS_OPTS="compress=zstd:3,noatime,ssd,discard=async"
mount -o "subvol=@,${BTRFS_OPTS}"      "${PART_ROOT}" /mnt
mkdir -p /mnt/{home,nix,boot}
mount -o "subvol=@home,${BTRFS_OPTS}"  "${PART_ROOT}" /mnt/home
mount -o "subvol=@nix,${BTRFS_OPTS}"   "${PART_ROOT}" /mnt/nix
mount "${PART_EFI}" /mnt/boot

# ═════════════════════════════════════════════════════════════════════════════
# [5] HARDWARE CONFIG
# ═════════════════════════════════════════════════════════════════════════════
info "[5/9] Generating hardware configuration..."
nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix /tmp/hardware-configuration.nix
rm -rf /mnt/etc/nixos

# ═════════════════════════════════════════════════════════════════════════════
# [6] CLONE / UPDATE REPO
# ═════════════════════════════════════════════════════════════════════════════
info "[6/9] Fetching configuration repository..."
if [[ -d /mnt/etc/nixos/.git ]]; then
  warn "/mnt/etc/nixos already exists — pulling latest changes."
  git -C /mnt/etc/nixos pull --ff-only || warn "git pull failed; existing files kept."
else
  git clone "${REPO_URL}" /mnt/etc/nixos
fi
cp /tmp/hardware-configuration.nix /mnt/etc/nixos/hardware-configuration.nix

# ═════════════════════════════════════════════════════════════════════════════
# [7] COPY WINDOWS EFI
# ═════════════════════════════════════════════════════════════════════════════
info "[7/9] Copying Windows EFI files..."
if [[ -n "$WIN_EFI" ]]; then
  WIN_UUID="$(blkid "${WIN_EFI}" -s UUID -o value 2>/dev/null || true)"

  mkdir -p /mnt/windows-efi
  if mount "${WIN_EFI}" /mnt/windows-efi 2>/dev/null; then
    mkdir -p /mnt/boot/EFI
    if [[ -d /mnt/windows-efi/EFI/Microsoft ]]; then
      cp -r /mnt/windows-efi/EFI/Microsoft /mnt/boot/EFI/
      info "Windows EFI files copied successfully."
    else
      warn "EFI/Microsoft not found on ${WIN_EFI} — skipping."
    fi
    umount /mnt/windows-efi
  else
    warn "Could not mount ${WIN_EFI} — skipping Windows EFI copy."
  fi
  rmdir /mnt/windows-efi 2>/dev/null || true

  if [[ -n "$WIN_UUID" ]]; then
    echo
    echo "  ╔══════════════════════════════════════════════════╗"
    echo "  ║  Windows EFI UUID : ${WIN_UUID}"
    echo "  ║  Use this in modules/boot.nix → extraEntries    ║"
    echo "  ║  if GRUB's useOSProber does not detect Windows. ║"
    echo "  ╚══════════════════════════════════════════════════╝"
    echo
  fi
else
  info "No Windows EFI configured — skipping."
fi

# ═════════════════════════════════════════════════════════════════════════════
# [8] PASSWORD WITH CONFIRMATION LOOP
# ═════════════════════════════════════════════════════════════════════════════
info "[8/9] Setting user password for 'pc'..."

HASH=""
while true; do
  echo -n "  Enter password: "
  read -rs PASS1
  echo

  if [[ -z "$PASS1" ]]; then
    warn "Password cannot be empty. Please try again."
    continue
  fi

  echo -n "  Confirm password: "
  read -rs PASS2
  echo

  if [[ "$PASS1" != "$PASS2" ]]; then
    warn "Passwords do not match. Please try again."
    unset PASS1 PASS2
    continue
  fi

  # Generate SHA-512 hash (password never written to disk as plaintext)
  HASH="$(printf '%s' "$PASS1" | \
    nix --extra-experimental-features 'nix-command flakes' \
    run nixpkgs#mkpasswd -- -m sha-512 -s)"

  unset PASS1 PASS2
  info "Password accepted."
  break
done

# Safely escape hash for sed (handles $ and / in SHA-512 hashes)
ESCAPED_HASH="$(printf '%s\n' "$HASH" | sed 's/[\/&]/\\&/g')"
sed -i "s|hashedPassword = \"[^\"]*\";|hashedPassword = \"${ESCAPED_HASH}\";|" \
  /mnt/etc/nixos/configuration.nix
info "Password hash written to configuration.nix."

# ═════════════════════════════════════════════════════════════════════════════
# [9] NIXOS-INSTALL
# ═════════════════════════════════════════════════════════════════════════════
info "[9/9] Installing NixOS..."
cd /mnt/etc/nixos
git add -A

export NIX_CONFIG="experimental-features = nix-command flakes
accept-flake-config = true"

nixos-install --flake "/mnt/etc/nixos#${FLAKE_HOST}" --no-root-passwd

echo
echo -e "${GREEN}=== Installation complete ===${NC}"
echo
echo "Next steps:"
echo "  1. Reboot — keep Secure Boot DISABLED."
echo "  2. Log in as 'pc' on the new NixOS system."
echo "  3. Run: sudo /etc/nixos/post-boot-secureboot.sh"
echo "  4. Reboot → enable Secure Boot in UEFI firmware settings."
echo "  5. Verify: sbctl status  (should show 'Secure Boot: enabled')"

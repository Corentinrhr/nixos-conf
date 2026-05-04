#!/usr/bin/env bash
# post-boot-secureboot.sh — GRUB2 + sbctl Secure Boot setup
# Run once after first boot with Secure Boot DISABLED and Setup Mode ACTIVE.
set -euo pipefail

FLAKE_HOST="nixos"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

echo "=== Secure Boot setup (GRUB2 + sbctl) ==="
[[ "$(id -u)" -ne 0 ]] && err "Run as root (sudo ./post-boot-secureboot.sh)."

# ── [1/6] Create keys ─────────────────────────────────────────────────────────
echo
info "[1/6] Creating Secure Boot keys..."

# Guard: if keys already exist from a previous run, skip creation
if [[ -f /var/lib/sbctl/keys/db/db.key ]]; then
  warn "Keys already exist at /var/lib/sbctl — skipping creation."
  warn "If you want to regenerate keys: sudo rm -rf /var/lib/sbctl && rerun."
else
  sbctl create-keys
fi

# ── [2/6] Enroll keys ────────────────────────────────────────────────────────
echo
info "[2/6] Enrolling keys with Microsoft certificates..."
info "NOTE: Your firmware must be in Setup Mode for this to work."
info "If you see 'not in Setup Mode', reboot → UEFI → delete all Secure Boot keys → save → reboot."
echo

sbctl enroll-keys --microsoft

# ── [3/6] Rebuild boot entries ───────────────────────────────────────────────
echo
info "[3/6] Rebuilding NixOS (boot target)..."
nixos-rebuild boot --flake "/etc/nixos#${FLAKE_HOST}"

# ── [4/6] Sign all EFI binaries ──────────────────────────────────────────────
echo
info "[4/6] Signing EFI binaries..."

# Discover actual GRUB EFI path dynamically instead of hardcoding
GRUB_EFI=""
for candidate in \
  /boot/EFI/NixOS-boot/grubx64.efi \
  /boot/EFI/BOOT/BOOTX64.EFI \
  /boot/EFI/grub/grubx64.efi; do
  if [[ -f "$candidate" ]]; then
    GRUB_EFI="$candidate"
    break
  fi
done

if [[ -z "$GRUB_EFI" ]]; then
  warn "Could not auto-detect GRUB EFI binary. Scanning /boot/EFI/..."
  GRUB_EFI="$(find /boot/EFI -name 'grubx64.efi' ! -path '*/Microsoft/*' 2>/dev/null | head -1)"
fi

if [[ -n "$GRUB_EFI" ]]; then
  info "Signing GRUB: $GRUB_EFI"
  sbctl sign -s "$GRUB_EFI"
else
  err "No grubx64.efi found under /boot/EFI. Is GRUB installed correctly?"
fi

# Sign GRUB internal modules (present after nixos-rebuild)
[[ -f /boot/grub/x86_64-efi/core.efi ]] && sbctl sign -s /boot/grub/x86_64-efi/core.efi
[[ -f /boot/grub/x86_64-efi/grub.efi ]] && sbctl sign -s /boot/grub/x86_64-efi/grub.efi

# ── [5/6] Sign all kernels ───────────────────────────────────────────────────
echo
info "[5/6] Signing kernels in /boot/kernels/..."

SIGNED_COUNT=0
for kernel in /boot/kernels/*; do
  [[ -f "$kernel" ]] || continue
  sbctl sign -s "$kernel"
  SIGNED_COUNT=$((SIGNED_COUNT + 1))
  info "  Signed: $(basename "$kernel")"
done

if [[ $SIGNED_COUNT -eq 0 ]]; then
  warn "No kernels found in /boot/kernels/ — trying sbctl sign-all as fallback..."
  sbctl sign-all || true
fi

# ── [6/6] Verify ─────────────────────────────────────────────────────────────
echo
info "[6/6] Verification..."
echo
echo "--- sbctl status ---"
sbctl status
echo
echo "--- sbctl verify (NixOS files only) ---"
# Filter out Microsoft files — they are signed by MS cert, not ours, and that's correct
sbctl verify 2>&1 | grep -v "EFI/Microsoft" | grep -v "EFI/microsoft" || true
echo
echo "--- EFI boot entries ---"
efibootmgr -v

echo
echo -e "${GREEN}=== Secure Boot preparation complete ===${NC}"
echo
echo "All NixOS EFI + kernel files should show '✓ signed' above."
echo "Microsoft files showing '✗' is NORMAL — they use Microsoft's own certificate."
echo
echo "Next steps:"
echo "  1. Reboot into UEFI firmware settings"
echo "  2. Set NixOS SSD as first boot device"
echo "  3. ENABLE Secure Boot"
echo "  4. Save and reboot"
echo "  5. After booting into NixOS, verify:"
echo "       sbctl status   →  Secure Boot: ✓ Enabled"
echo "       sbctl verify   →  all NixOS files signed"
echo
echo "Future nixos-rebuild runs will auto-sign new kernels via"
echo "boot.loader.grub.extraInstallCommands in modules/boot.nix."
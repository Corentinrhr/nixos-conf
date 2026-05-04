#!/usr/bin/env bash
set -euo pipefail

FLAKE_HOST="nixos"

echo "=== Secure Boot setup (GRUB2 + sbctl) ==="
[[ "$(id -u)" -ne 0 ]] && { echo "Run as root."; exit 1; }

echo "[1/6] Installing sbctl and creating keys..."
# sbctl should already be in PATH from packages.nix
sbctl create-keys

echo "[2/6] Enrolling keys with Microsoft certificates..."
# --microsoft ensures Windows boot entries remain valid
sbctl enroll-keys --microsoft

echo "[3/6] Rebuilding NixOS boot entries..."
nixos-rebuild boot --flake "/etc/nixos#${FLAKE_HOST}"

echo "[4/6] Signing GRUB EFI binary..."
sbctl sign -s /boot/EFI/GRUB/grubx64.efi

echo "[5/6] Signing all kernels..."
# sbctl sign-all signs everything registered in the database
sbctl sign-all

echo "[6/6] Verifying..."
echo "--- sbctl status ---"
sbctl status
echo "--- sbctl verify ---"
sbctl verify
echo "--- EFI boot entries ---"
efibootmgr -v

echo
echo "=== Secure Boot preparation complete ==="
echo "Next steps:"
echo "1. Reboot into UEFI firmware settings"
echo "2. Set boot order: NixOS SSD first"
echo "3. Enable Secure Boot (it should be in 'User Mode' after key enrollment)"
echo "4. Save and reboot — both NixOS and Windows should boot correctly"
echo
echo "To verify post-reboot: run 'sbctl status' — should show 'Secure Boot: enabled'"
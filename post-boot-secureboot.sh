#!/usr/bin/env bash
set -euo pipefail

FLAKE_HOST="nixos"

echo "=== Secure Boot post-install setup ==="

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: please run this script as root."
  exit 1
fi

echo "[1/4] Creating Secure Boot keys..."
sbctl create-keys

echo "[2/4] Enrolling keys, including Microsoft keys for Windows compatibility..."
sbctl enroll-keys --microsoft

echo "[3/4] Rebuilding system so boot files are signed..."
nixos-rebuild switch --flake "/etc/nixos#${FLAKE_HOST}"

echo "[4/4] Verifying Secure Boot status..."
sbctl status
sbctl verify
bootctl status

echo
echo "=== Secure Boot setup completed ==="
echo "Next steps:"
echo "1. Reboot into your motherboard firmware settings."
echo "2. Set the NixOS SSD as the first boot device."
echo "3. Enable Secure Boot."
echo "4. Save and reboot."

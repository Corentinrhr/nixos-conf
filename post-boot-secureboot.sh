#!/usr/bin/env bash
set -euo pipefail

FLAKE_HOST="nixos"
CONFIG_FILE="/etc/nixos/configuration.nix"

echo "=== Secure Boot post-install setup ==="

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: please run this script as root."
  exit 1
fi

if [ ! -f "${CONFIG_FILE}" ]; then
  echo "Error: ${CONFIG_FILE} not found."
  exit 1
fi

echo "[1/5] Enabling Lanzaboote in configuration.nix..."
if grep -q "useLanzaboote = false;" "${CONFIG_FILE}"; then
  sed -i 's/useLanzaboote = false;/useLanzaboote = true;/' "${CONFIG_FILE}"
else
  echo "Warning: useLanzaboote flag was not found or is already enabled."
fi

if [ -d /etc/nixos/.git ]; then
  git -C /etc/nixos add configuration.nix || true
fi

echo "[2/5] Creating Secure Boot keys..."
sbctl create-keys

echo "[3/5] Enrolling keys, including Microsoft keys..."
sbctl enroll-keys --microsoft

echo "[4/5] Building boot entries with Lanzaboote..."
nixos-rebuild boot --flake "/etc/nixos#${FLAKE_HOST}"

echo "[5/5] Verifying status..."
sbctl status
sbctl verify
bootctl status

echo
echo "=== Secure Boot setup completed ==="
echo "Next steps:"
echo "1. Reboot into your firmware settings."
echo "2. Set the NixOS SSD as the first boot device."
echo "3. Enable Secure Boot."
echo "4. Save and reboot."
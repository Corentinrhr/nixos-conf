#!/usr/bin/env bash
# update.sh — NixOS configuration updater
# 1. Sync with remote git repo (discard local changes)
# 2. Generate hardware-configuration.nix if missing
# 3. Update password hash in configuration.nix
# 4. Find and patch Windows EFI UUID in modules/boot.nix
# 5. Commit and nixos-rebuild switch
set -euo pipefail

FLAKE_HOST="nixos"
NIXOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_NIX="${NIXOS_DIR}/configuration.nix"
BOOT_NIX="${NIXOS_DIR}/modules/boot.nix"
HW_CONFIG="${NIXOS_DIR}/hardware-configuration.nix"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
step()  { echo -e "\n${CYAN}══ $* ══${NC}"; }

[[ "$(id -u)" -ne 0 ]] && err "Run as root: sudo ./update.sh"

# ═══════════════════════════════════════════════════════════════════════════════
# [1] SYNC WITH REMOTE (discard local changes, pull latest)
# ═══════════════════════════════════════════════════════════════════════════════
step "Syncing with remote repository"

cd "$NIXOS_DIR"

# Verify this is a git repo with a remote
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  err "${NIXOS_DIR} is not a git repository."
fi

REMOTE="$(git remote 2>/dev/null | head -1 || true)"
if [[ -z "$REMOTE" ]]; then
  warn "No git remote configured — skipping sync."
else
  # Save hardware-configuration.nix before reset — it is machine-specific
  # and is gitignored / not in the remote repo
  HW_BACKUP=""
  if [[ -f "$HW_CONFIG" ]]; then
    HW_BACKUP="$(mktemp)"
    cp "$HW_CONFIG" "$HW_BACKUP"
    info "Saved hardware-configuration.nix before reset."
  fi

  # Save current password hash and Windows UUID — they are local values
  # that must survive the reset
  SAVED_HASH="$(grep -oP '(?<=hashedPassword = ")[^"]+' "$CONFIG_NIX" 2>/dev/null || true)"
  SAVED_UUID="$(grep -oP '(?<=--set=root )[A-F0-9a-f-]{4,}' "$BOOT_NIX" 2>/dev/null || true)"

  info "Fetching remote changes..."
  git fetch --all --prune

  BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || echo 'main')"
  info "Resetting to ${REMOTE}/${BRANCH}..."

  # Hard reset discards ALL local modifications and matches remote exactly
  git reset --hard "${REMOTE}/${BRANCH}"
  git clean -fd --exclude='hardware-configuration.nix' --exclude='flake.lock'

  info "Repository is now in sync with ${REMOTE}/${BRANCH}."

  # Restore hardware-configuration.nix (machine-specific, not in remote)
  if [[ -n "$HW_BACKUP" ]] && [[ -f "$HW_BACKUP" ]]; then
    cp "$HW_BACKUP" "$HW_CONFIG"
    rm -f "$HW_BACKUP"
    info "Restored hardware-configuration.nix."
  fi

  # Re-apply saved password hash if the remote still has a placeholder
  if [[ -n "$SAVED_HASH" ]] && [[ "$SAVED_HASH" != *"REPLACE_THIS"* ]]; then
    CURRENT_HASH_AFTER="$(grep -oP '(?<=hashedPassword = ")[^"]+' "$CONFIG_NIX" 2>/dev/null || true)"
    if [[ "$CURRENT_HASH_AFTER" == *"REPLACE_THIS"* ]]; then
      ESCAPED="$(printf '%s\n' "$SAVED_HASH" | sed 's/[\/&]/\\&/g')"
      sed -i "s|hashedPassword = \"[^\"]*\";|hashedPassword = \"${ESCAPED}\";|" "$CONFIG_NIX"
      info "Re-applied saved password hash."
    fi
  fi

  # Re-apply saved Windows UUID if the remote still has a placeholder
  if [[ -n "$SAVED_UUID" ]] && [[ "$SAVED_UUID" != *"REPLACE"* ]]; then
    CURRENT_UUID_AFTER="$(grep -oP '(?<=--set=root )[A-F0-9a-f-]{4,}' "$BOOT_NIX" 2>/dev/null || true)"
    if [[ "$CURRENT_UUID_AFTER" == *"REPLACE"* ]] || [[ -z "$CURRENT_UUID_AFTER" ]]; then
      sed -i "s|REPLACE_WITH_WIN_EFI_UUID|${SAVED_UUID}|g" "$BOOT_NIX"
      info "Re-applied saved Windows EFI UUID."
    fi
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# [2] HARDWARE CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════
step "Hardware configuration"

if [[ ! -f "$HW_CONFIG" ]]; then
  warn "hardware-configuration.nix not found — generating..."
  nixos-generate-config --dir "$NIXOS_DIR"
  info "Generated: $HW_CONFIG"
else
  info "hardware-configuration.nix present."
  echo -n "  Regenerate it? [y/N] "
  read -r REGEN
  if [[ "${REGEN,,}" == "y" ]]; then
    nixos-generate-config --dir "$NIXOS_DIR"
    info "Regenerated: $HW_CONFIG"
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# [3] PASSWORD HASH
# ═══════════════════════════════════════════════════════════════════════════════
step "User password"

CURRENT_HASH="$(grep -oP '(?<=hashedPassword = ")[^"]+' "$CONFIG_NIX" 2>/dev/null || true)"

if [[ "$CURRENT_HASH" == *"REPLACE_THIS"* ]] || [[ -z "$CURRENT_HASH" ]]; then
  warn "Password placeholder detected — a real hash is required."
  DO_PASS=true
else
  info "Password hash already set: ${CURRENT_HASH:0:20}..."
  echo -n "  Update the password? [y/N] "
  read -r _CH; DO_PASS="${_CH,,}"
fi

if [[ "$DO_PASS" == "true" ]] || [[ "$DO_PASS" == "y" ]]; then
  while true; do
    echo -n "  Enter new password for user 'pc': "
    read -rs PASS1; echo
    [[ -z "$PASS1" ]] && { warn "Password cannot be empty."; continue; }
    echo -n "  Confirm password: "
    read -rs PASS2; echo
    if [[ "$PASS1" != "$PASS2" ]]; then
      warn "Passwords do not match. Try again."
      unset PASS1 PASS2; continue
    fi
    HASH="$(printf '%s' "$PASS1" | mkpasswd -m sha-512 -s)"
    unset PASS1 PASS2
    ESCAPED="$(printf '%s\n' "$HASH" | sed 's/[\/&]/\\&/g')"
    sed -i "s|hashedPassword = \"[^\"]*\";|hashedPassword = \"${ESCAPED}\";|" "$CONFIG_NIX"
    info "Password hash written to configuration.nix."
    break
  done
else
  info "Password unchanged."
fi

# ═══════════════════════════════════════════════════════════════════════════════
# [4] WINDOWS EFI UUID
# ═══════════════════════════════════════════════════════════════════════════════
step "Windows EFI UUID"

CURRENT_UUID="$(grep -oP '(?<=--set=root )[A-F0-9a-f-]{4,}' "$BOOT_NIX" 2>/dev/null || true)"

_scan_win_uuid() {
  local found_uuid=""
  for part in $(blkid -t TYPE=vfat -o device 2>/dev/null); do
    local TMP_MNT; TMP_MNT="$(mktemp -d)"
    if mount -o ro "$part" "$TMP_MNT" 2>/dev/null; then
      if [[ -d "${TMP_MNT}/EFI/Microsoft" ]]; then
        found_uuid="$(blkid "$part" -s UUID -o value 2>/dev/null || true)"
        umount "$TMP_MNT"; rmdir "$TMP_MNT"
        break
      fi
      umount "$TMP_MNT"
    fi
    rmdir "$TMP_MNT" 2>/dev/null || true
  done
  echo "$found_uuid"
}

if [[ "$CURRENT_UUID" == *"REPLACE"* ]] || [[ -z "$CURRENT_UUID" ]]; then
  info "Scanning for Windows EFI partition..."
  WIN_UUID="$(_scan_win_uuid)"
  if [[ -n "$WIN_UUID" ]]; then
    sed -i "s|REPLACE_WITH_WIN_EFI_UUID|${WIN_UUID}|g" "$BOOT_NIX"
    info "UUID written to modules/boot.nix: ${WIN_UUID}"
  else
    warn "No Windows EFI found — UUID left as placeholder."
  fi
else
  info "Windows EFI UUID already set: ${CURRENT_UUID}"
  echo -n "  Re-scan and update it? [y/N] "
  read -r _RS
  if [[ "${_RS,,}" == "y" ]]; then
    WIN_UUID="$(_scan_win_uuid)"
    if [[ -n "$WIN_UUID" ]]; then
      sed -i "s|${CURRENT_UUID}|${WIN_UUID}|g" "$BOOT_NIX"
      info "UUID updated: ${WIN_UUID}"
    else
      warn "No Windows EFI found — UUID unchanged."
    fi
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# [5] GIT COMMIT (local changes only — hw config + patched values)
# ═══════════════════════════════════════════════════════════════════════════════
step "Committing local patches"

cd "$NIXOS_DIR"
git add -A

if git diff --cached --quiet; then
  info "Nothing to commit."
else
  git commit -m "update: $(date '+%Y-%m-%d %H:%M') — local patches (hw-config, password, uuid)"
  info "Local patches committed."
fi

# ═══════════════════════════════════════════════════════════════════════════════
# [6] NIXOS-REBUILD
# ═══════════════════════════════════════════════════════════════════════════════
step "NixOS rebuild"

info "Running: nixos-rebuild switch --flake path://${NIXOS_DIR}#${FLAKE_HOST}"
nixos-rebuild switch \
  --flake "path://${NIXOS_DIR}#${FLAKE_HOST}" \
  --accept-flake-config

echo
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  NixOS updated and rebuilt successfully.      ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo
info "Current generation:"
nixos-rebuild list-generations 2>/dev/null | tail -3 || true
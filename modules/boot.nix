{ config, pkgs, lib, ... }:
{
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.loader.timeout = 3;

  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    useOSProber = true;
    enableCryptodisk = false;
    splashImage = null;

    # Sign all NixOS EFI binaries and kernels after every bootloader install.
    # This covers: initial install, nixos-rebuild switch/boot, and generation
    # changes. grub-mkstandalone is intentionally NOT used here — the standard
    # NixOS-built grubx64.efi works correctly once properly signed.
    extraInstallCommands = ''
      set -euo pipefail

      SBCTL="${pkgs.sbctl}/bin/sbctl"

      # Discover the real GRUB EFI path installed by NixOS (never hardcode)
      GRUB_EFI=""
      for candidate in \
        /boot/EFI/NixOS-boot/grubx64.efi \
        /boot/EFI/BOOT/BOOTX64.EFI \
        /boot/EFI/grub/grubx64.efi; do
        if [ -f "$candidate" ]; then
          GRUB_EFI="$candidate"
          break
        fi
      done

      if [ -z "$GRUB_EFI" ]; then
        GRUB_EFI="$(find /boot/EFI -name 'grubx64.efi' \
          ! -path '*/Microsoft/*' 2>/dev/null | head -1 || true)"
      fi

      # Sign GRUB EFI binary
      if [ -n "$GRUB_EFI" ]; then
        "$SBCTL" sign -s "$GRUB_EFI" 2>/dev/null || true
      fi

      # Sign GRUB internal modules (present after grub install)
      [ -f /boot/grub/x86_64-efi/core.efi ] && \
        "$SBCTL" sign -s /boot/grub/x86_64-efi/core.efi 2>/dev/null || true
      [ -f /boot/grub/x86_64-efi/grub.efi ] && \
        "$SBCTL" sign -s /boot/grub/x86_64-efi/grub.efi 2>/dev/null || true

      # Sign every kernel in /boot/kernels/ — filename changes on each rebuild
      for k in /boot/kernels/*; do
        [ -f "$k" ] && "$SBCTL" sign -s "$k" 2>/dev/null || true
      done
    '';
  };

  boot.loader.systemd-boot.enable = false;

  environment.systemPackages = with pkgs; [
    sbctl
    efibootmgr
    grub2_efi   # provides grub-mkstandalone if ever needed manually
  ];

  # Fallback manual Windows entry.
  # Replace REPLACE_WITH_WIN_EFI_UUID with output of:
  #   blkid /dev/<windows-efi-partition> -s UUID -o value
  # This is only a fallback — useOSProber = true handles it automatically
  # when Windows is on a different disk.
  boot.loader.grub.extraEntries = ''
    menuentry "Windows 11" {
      insmod part_gpt
      insmod fat
      insmod chain
      search --no-floppy --fs-uuid --set=root REPLACE_WITH_WIN_EFI_UUID
      chainloader /EFI/Microsoft/Boot/bootmgfw.efi
    }
  '';
}
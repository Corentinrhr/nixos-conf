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

    # Auto-sign every kernel in /boot/kernels/ after each GRUB install.
    # This runs after nixos-rebuild writes the new kernel, ensuring
    # Secure Boot never rejects a freshly built generation.
    extraInstallCommands = ''
      echo "[sbctl] Signing EFI binaries and kernels after GRUB install..."

      # Sign GRUB binaries (idempotent — already in db, safe to re-sign)
      ${pkgs.sbctl}/bin/sbctl sign -s /boot/EFI/NixOS-boot/grubx64.efi  2>/dev/null || true
      ${pkgs.sbctl}/bin/sbctl sign -s /boot/grub/x86_64-efi/core.efi    2>/dev/null || true
      ${pkgs.sbctl}/bin/sbctl sign -s /boot/grub/x86_64-efi/grub.efi    2>/dev/null || true

      # Sign every kernel in /boot/kernels/ (hash changes on each generation)
      for k in /boot/kernels/*; do
        [ -f "$k" ] && ${pkgs.sbctl}/bin/sbctl sign -s "$k" 2>/dev/null || true
      done

      echo "[sbctl] Signing complete."
    '';
  };

  boot.loader.systemd-boot.enable = false;

  environment.systemPackages = [ pkgs.sbctl pkgs.efibootmgr ];

  # Fallback manual Windows entry — replace UUID if useOSProber misses it.
  # Get the UUID with: blkid /dev/<windows-efi-partition> -s UUID -o value
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
{ config, pkgs, lib, ... }:
{
  # GRUB2 as bootloader — stable, Secure Boot compatible via sbctl
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.loader.timeout = 3;

  boot.loader.grub = {
    enable = true;
    device = "nodev";        # EFI-only, no MBR write
    efiSupport = true;
    useOSProber = true;      # Automatically detects Windows on other drives
    enableCryptodisk = false;
    # GRUB theme (optional, comment out if not desired)
    splashImage = null;
  };

  boot.loader.systemd-boot.enable = false;

  # sbctl is used post-install to sign GRUB and kernels for Secure Boot
  # See post-boot-secureboot.sh for the signing workflow
  environment.systemPackages = [ pkgs.sbctl pkgs.efibootmgr ];

  # os-prober needs to be enabled at the NixOS level
  boot.loader.grub.extraEntries = ''
    menuentry "Windows 11" {
      insmod part_gpt
      insmod fat
      insmod chain
      search --no-floppy --fs-uuid --set=root $WIN_EFI_UUID
      chainloader /EFI/Microsoft/Boot/bootmgfw.efi
    }
  '';
  # NOTE: Replace $WIN_EFI_UUID with your actual Windows EFI partition UUID
  # Run: blkid /dev/nvme0n1p1 (or wherever your Windows EFI is) to get it
  # Alternatively, useOSProber = true handles this automatically if os-prober
  # is installed and the Windows partition is on a different disk.
}
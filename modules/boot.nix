{ config, pkgs, lib, ... }:
{
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.loader.timeout = 3;

  # systemd-boot is required by lanzaboote but must be disabled
  # (lanzaboote replaces it with its own signed stub)
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.grub.enable = false;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";  # reuses your existing sbctl keys
  };

  environment.systemPackages = with pkgs; [
    sbctl
    efibootmgr
  ];
}
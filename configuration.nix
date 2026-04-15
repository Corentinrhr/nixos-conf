{ config, pkgs, lib, ... }:

let
  useLanzaboote = false;
in
{
  imports = [
    ./modules/audio.nix
    ./modules/gaming.nix
    ./modules/kernel.nix
    ./modules/ntp.nix
    ./modules/packages.nix
    ./modules/security.nix
    ./modules/swap.nix
    ./modules/tz.nix
  ];

  # Bootloader
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.loader.timeout = 3;

  boot.loader.grub.enable = false;
  boot.loader.systemd-boot.enable = lib.mkForce (!useLanzaboote);

  boot.lanzaboote = lib.mkIf useLanzaboote {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };

  # Windows entry
  boot.loader.systemd-boot.extraEntries."windows.conf" = ''
    title Windows
    efi /EFI/Microsoft/Boot/bootmgfw.efi
  '';

  # Host and networking
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # Desktop
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gnome ];

  # AMD graphics
  services.xserver.videoDrivers = [ "amdgpu" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.amd.updateMicrocode = true;
  hardware.bluetooth.enable = true;

  services.fwupd.enable = true;
  services.fstrim.enable = true;

  users.users.pc = {
    isNormalUser = true;
    description = "Main User";
    extraGroups = [ "networkmanager" "wheel" "video" ];
    hashedPassword = "$6$REPLACE_THIS_WITH_YOUR_HASH";
  };

  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    download-buffer-size = 524288000;
  };

  system.stateVersion = "25.11";
}
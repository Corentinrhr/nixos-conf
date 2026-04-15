{ config, pkgs, lib, ... }:

{
  imports = [
    ./audio.nix
    ./gaming.nix
    ./kernel.nix
    ./ntp.nix
    ./packages.nix
    ./security.nix
    ./swap.nix
    ./tz.nix
  ];

  # Bootloader and Secure Boot
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.loader.timeout = 3;

  # Lanzaboote manages the boot chain
  boot.loader.systemd-boot.enable = lib.mkForce false;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };

  # Windows menu entry
  # This works when /EFI/Microsoft/Boot/bootmgfw.efi exists on the same ESP mounted at /boot.
  boot.loader.systemd-boot.extraEntries."windows.conf" = ''
    title Windows
    efi /EFI/Microsoft/Boot/bootmgfw.efi
  '';

  # Host and networking
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # GNOME desktop
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Wayland/Electron quality of life
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

  # Firmware updates
  services.fwupd.enable = true;

  # SSD maintenance
  services.fstrim.enable = true;

  # User account
  users.users.pc = {
    isNormalUser = true;
    description = "Main User";
    extraGroups = [ "networkmanager" "wheel" "video" ];
    hashedPassword = "$6$REPLACE_THIS_WITH_YOUR_HASH";
  };

  # Nix
  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "25.11";
}
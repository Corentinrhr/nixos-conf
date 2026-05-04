{ config, pkgs, lib, ... }:
{
  imports = [
    ./modules/audio.nix
    ./modules/boot.nix
    ./modules/gaming.nix
    ./modules/gpu-amd.nix
    ./modules/ai.nix
    ./modules/kernel.nix
    ./modules/locale.nix
    ./modules/ntp.nix
    ./modules/packages.nix
    ./modules/security.nix
    ./modules/swap.nix
  ];

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # Desktop environment
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gnome ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  # Hardware
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.amd.updateMicrocode = true;
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  services.fwupd.enable = true;
  services.fstrim.enable = true;

  # User
  users.users.pc = {
    isNormalUser = true;
    description = "Main User";
    extraGroups = [ "networkmanager" "wheel" "video" "render" "gamemode" ];
    # Generate with: mkpasswd -m sha-512
    hashedPassword = "$6$REPLACE_THIS_WITH_YOUR_HASH";
  };

  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    download-buffer-size = 524288000;
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
  
  system.stateVersion = "25.11";
}
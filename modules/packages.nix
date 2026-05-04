{ config, pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    # System utilities
    git wget curl nano vim fastfetch
    sbctl efibootmgr mkpasswd
    pciutils usbutils lshw
    # GPU/graphics diagnostics
    vulkan-tools mesa-demos clinfo
    # Gaming overlays (system-level; user-level via gaming.nix)
    mangohud
    # Monitoring
    htop btop nvtopPackages.amd
  ];

  users.users.pc.packages = with pkgs; [
    gnome-tweaks
    gnome-extension-manager
    gnomeExtensions.appindicator
  ];

  # Flatpak: declarative, no third-party flake needed in nixpkgs 25.11
  services.flatpak = {
    enable = true;
    # Note: declarative package management in nixpkgs flatpak service
    # requires manual `flatpak install` or an activation script post-install
  };

  # Add Flathub remote
  systemd.user.services.add-flathub = {
    description = "Add Flathub remote to Flatpak";
    wantedBy = [ "default.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.flatpak}/bin/flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo";
    };
  };
}
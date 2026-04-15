{ config, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    wget
    curl
    nano
    vim
    fastfetch
    sbctl
    mkpasswd
    pciutils
    usbutils
    lshw
    vulkan-tools
    mesa-demos
    mangohud
    gamescope
  ];

  users.users.pc.packages = with pkgs; [
    gnome-tweaks
    gnome-extension-manager
    gnomeExtensions.appindicator
  ];

  services.flatpak = {
    enable = true;
    remotes = lib.mkOptionDefault [
      {
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
    ];
    packages = [
      "com.brave.Browser"
      "org.videolan.VLC"
      "dev.vencord.Vesktop"
      "com.github.iwalton3.jellyfin-media-player"
    ];
  };
}
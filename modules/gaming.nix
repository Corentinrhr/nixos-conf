{ config, pkgs, ... }:

{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
    gamescopeSession.enable = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };

  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 10;
        ioprio = 0;
      };
      gpu = {
        apply_gpu_optimizations = "accept-responsibility";
        amd_performance_level = "high";
      };
    };
  };

  hardware.steam-hardware.enable = true;

  environment.systemPackages = with pkgs; [
    mangohud      # GPU/CPU overlay (Vulkan + OpenGL)
    gamescope     # Wayland micro-compositor
    lutris        # Multi-platform game manager
    heroic        # Epic / GOG / Amazon Games launcher
    protonup-qt   # Proton-GE version manager (GUI)
    winetricks
  ];
}
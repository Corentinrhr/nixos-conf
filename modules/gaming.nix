{ config, pkgs, lib, ... }:
{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false; # Only enable if you host game servers
    gamescopeSession.enable = true;
    # Proton-GE is best managed per-user via ProtonUp-Qt
    # or Steam's built-in Proton manager
    extraCompatPackages = with pkgs; [
      proton-ge-bin  # Pre-built, no compilation
    ];
  };

  programs.gamescope = {
    enable = true;
    capSysNice = true;  # Allows gamescope to use nice priorities
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

  # MangoHud: performance overlay
  programs.mangohud.enable = true;

  # Optional gaming tools
  environment.systemPackages = with pkgs; [
    lutris          # Multi-platform game manager
    heroic          # Epic/GOG launcher
    protonup-qt     # Proton-GE manager (user-space)
    winetricks
  ];
}
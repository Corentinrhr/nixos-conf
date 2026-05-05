{ config, pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    # ── System utilities ────────────────────────────────────────────────────
    git wget curl nano vim fastfetch
    sbctl efibootmgr mkpasswd
    pciutils usbutils lshw
    unzip zip p7zip
    tree ripgrep fd bat
    gnome-tweaks
    flameshot

    # ── GPU / graphics diagnostics ──────────────────────────────────────────
    vulkan-tools mesa-demos clinfo

    # ── Gaming overlays (system-level; per-user also in gaming.nix) ─────────
    mangohud

    # ── Monitoring ──────────────────────────────────────────────────────────
    htop btop nvtopPackages.amd

    # ── Browsers ────────────────────────────────────────────────────────────
    brave
    google-chrome

    # ── Editor ──────────────────────────────────────────────────────────────
    vscodium                  # VSCode without telemetry

    # ── Python dev stack ────────────────────────────────────────────────────
    python313                 # Latest stable Python
    python313Packages.pip
    python313Packages.virtualenv
    uv                        # Fast Python package manager (replaces pip/venv)
    ruff                      # Python linter + formatter
    pyright                   # Python LSP (works in VSCodium)

    # ── General dev tools ────────────────────────────────────────────────────
    gcc gnumake cmake ninja
    pkg-config
    docker-compose
    jq yq                     # JSON / YAML processors
    httpie                    # curl with a human face
    gh                        # GitHub CLI
    meld                      # Visual diff / merge tool
  ];

  # ── Docker ────────────────────────────────────────────────────────────────
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;     # Start on demand (socket activation)
    autoPrune.enable = true;
  };
  users.users.pc.extraGroups = [ "docker" ];

  # ── Per-user GNOME packages ───────────────────────────────────────────────
  users.users.pc.packages = with pkgs; [
    gnome-tweaks
    gnome-extension-manager
    gnomeExtensions.appindicator
  ];

  # ── Flatpak ───────────────────────────────────────────────────────────────
  services.flatpak.enable = true;

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
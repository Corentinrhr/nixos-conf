{ config, pkgs, ... }:

{
  # CachyOS kernel from nix-cachyos-kernel overlay
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;

  # Binary cache for prebuilt kernels
  nix.settings.substituters = [
    "https://cache.nixos.org"
    "https://attic.xuyh0120.win/lantian"
  ];

  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbVQh5ZPmF2xKQ2r9FzYv6J9c="
    "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
  ];

  # Latency-oriented kernel parameters
  boot.kernelParams = [
    "preempt=full"
    "threadirqs"
  ];

  # Optional: enable this later if you specifically want sched-ext tuning
  # services.scx = {
  #   enable = true;
  #   scheduler = "scx_lavd";
  # };
}
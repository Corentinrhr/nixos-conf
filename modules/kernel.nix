{ config, pkgs, ... }:

{
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;

  nix.settings.substituters = [
    "https://cache.nixos.org"
    "https://attic.xuyh0120.win/lantian"
  ];

  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbVQh5ZPmF2xKQ2r9FzYv6J9c="
    "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
  ];

  boot.kernelParams = [
    "preempt=full"
    "threadirqs"
  ];
}
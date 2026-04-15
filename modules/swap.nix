{ config, pkgs, ... }:

{
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.page-cluster" = 6;
    "vm.vfs_cache_pressure" = 50;
  };
}
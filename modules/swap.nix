{ config, pkgs, ... }:
{
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50; # 50% is safer; increase to 100% if you frequently use >RAM
    priority = 100;
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 180;            # Aggressively use zram swap
    "vm.page-cluster" = 0;            # 0 for zram
    "vm.vfs_cache_pressure" = 50;     # Keep dentries/inodes cached longer
    "vm.watermark_boost_factor" = 0;  # Reduce unnecessary reclaim
    "vm.watermark_scale_factor" = 125;
    # Gaming: reduce dirty page writeback latency
    "vm.dirty_ratio" = 10;
    "vm.dirty_background_ratio" = 5;
  };
}
{ config, pkgs, ... }:
{
  # xanmod_latest: BORE scheduler, full preemption, latency-optimized
  # Fully binary-cached from nixpkgs - no source compilation
  boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;

  boot.kernelParams = [
    # Full preemption for low-latency response
    "preempt=full"
    # Move IRQ handling to threads - reduces latency spikes
    "threadirqs"
    # AMD-specific: disable IOMMU passthrough issues
    "amd_iommu=on"
    "iommu=pt"
    # CPU frequency: schedutil governor via kernel (set in udev/powertop later)
    "cpufreq.default_governor=performance"
  ];

  # CPU governor: performance mode for consistent low latency
  powerManagement.cpuFreqGovernor = "performance";
}
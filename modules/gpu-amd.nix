{ config, pkgs, ... }:
{
  # Modern AMDGPU driver stack — no need to explicitly list "amdgpu" in
  # videoDrivers for RDNA2/3/4; NixOS selects it automatically.
  # Explicit listing is kept for clarity but is not strictly required.
  services.xserver.videoDrivers = [ "amdgpu" ];

  hardware.amdgpu.opencl.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;  # Required for 32-bit Steam/Proton games
    extraPackages = with pkgs; [
      # ROCm compute stack
      rocmPackages.clr           # OpenCL + HIP runtime (replaces rocm-rtio)
      rocmPackages.rocm-runtime  # Correct runtime package
      rocmPackages.rocm-device-libs
      # Vulkan layers
      vulkan-loader
      vulkan-validation-layers
      amdvlk                     # AMD's official Vulkan driver (alongside RADV)
    ];
    extraPackages32 = with pkgs.pkgsi686Linux; [
      vulkan-loader
    ];
  };

  # ROCm symlink required by some tools (PyTorch, llama.cpp, etc.)
  systemd.tmpfiles.rules = [
    "L+ /opt/rocm/hip - - - - ${pkgs.rocmPackages.clr}"
  ];

  # Mesa/RADV performance environment variables
  environment.sessionVariables = {
    # Enable Graphics Pipeline Library for faster shader compilation
    RADV_PERFTEST = "gpl";
    # Enable Mesa GL threading
    mesa_glthread = "true";
    # AMD GPU override for RDNA3/4 (GFX 11/12) — adjust to your GPU
    # RX 7000 series = 11.x.x, RX 9000 series = 12.x.x
    HSA_OVERRIDE_GFX_VERSION = "12.0.0"; # <-- CHANGE THIS to match your GPU
  };
}
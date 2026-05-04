{ config, pkgs, ... }:
{
  # Ollama: local LLM backend with ROCm acceleration
  services.ollama = {
    enable = true;
    acceleration = "rocm";
    rocmOverrideGfx = "12.0.0"; # Match your GPU's GFX version
    # Isolated environment - not polluting global env
    environmentVariables = {
      HSA_OVERRIDE_GFX_VERSION = "12.0.0";
      OLLAMA_LLM_LIBRARY = "rocm";
    };
  };

  # llama-cpp with ROCm
  environment.systemPackages = with pkgs; [
    pkgs.llama-cpp-rocm
  ];
}
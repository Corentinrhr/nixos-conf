{ config, pkgs, ... }:
{
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;

    # Low-latency config: adaptive quantum, not locked
    # This allows PipeWire to adapt between 32 and 512 frames
    # for optimal gaming vs. audio quality trade-off
    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 64;     # ~1.3ms latency
        "default.clock.min-quantum" = 32; # Allows going lower if hardware supports
        "default.clock.max-quantum" = 512; # Falls back gracefully under load
      };
    };
  };
}
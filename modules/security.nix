{ config, pkgs, ... }:
{
  security.sudo.enable = false;
  security.sudo-rs = {
    enable = true;
    execWheelOnly = true;
    wheelNeedsPassword = true;
  };

  # Polkit (required by GNOME and many system services)
  security.polkit.enable = true;
}
{ config, pkgs, ... }:

{
  security.sudo.enable = false;

  security.sudo-rs = {
    enable = true;
    execWheelOnly = true;
    wheelNeedsPassword = true;
  };
}
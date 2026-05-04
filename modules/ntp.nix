{ config, pkgs, ... }:
{
  services.timesyncd.enable = false;

  services.chrony = {
    enable = true;
    extraConfig = ''
      pool 2.nixos.pool.ntp.org iburst
      makestep 1.0 3
    '';
  };
}
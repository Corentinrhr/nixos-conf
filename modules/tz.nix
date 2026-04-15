{ config, pkgs, ... }:

{
  time.timeZone = "Europe/Paris";

  i18n.defaultLocale = "fr_FR.UTF-8";

  services.xserver.xkb = {
    layout = "fr";
    variant = "";
  };

  console.keyMap = "fr";
}
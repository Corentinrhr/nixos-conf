{ config, pkgs, ... }:
{
  time.timeZone = "Europe/Paris";
  # Dual boot with Windows: keep hardware clock in UTC
  # Windows needs: reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation"
  # /v RealTimeIsUniversal /t REG_QWORD /d 1
  time.hardwareClockInLocalTime = false;

  i18n.defaultLocale = "fr_FR.UTF-8";
  i18n.supportedLocales = [
    "fr_FR.UTF-8/UTF-8"
    "en_US.UTF-8/UTF-8"
  ];

  services.xserver.xkb = {
    layout = "fr";
    variant = "";
  };

  console.keyMap = "fr";
}
{ config, pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    grim
    slurp
    wl-clipboard
  ];

  programs.dconf.enable = true;

  system.activationScripts.gnomeShortcuts = lib.mkAfter ''
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"
    export HOME=/home/pc

    ${pkgs.glib}/bin/gsettings set \
      org.gnome.settings-daemon.plugins.media-keys \
      custom-keybindings \
      "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']"

    BASE="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding"
    PATH_="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"

    ${pkgs.glib}/bin/gsettings set "$BASE:$PATH_" \
      name "Screenshot region → clipboard + save"

    ${pkgs.glib}/bin/gsettings set "$BASE:$PATH_" \
      command "bash -c 'mkdir -p \$HOME/Pictures/Screenshots; \
        F=\$HOME/Pictures/Screenshots/\$(date +%Y-%m-%d_%H-%M-%S).png; \
        ${pkgs.grim}/bin/grim -g \"\$(${pkgs.slurp}/bin/slurp)\" \$F && \
        ${pkgs.wl-clipboard}/bin/wl-copy < \$F'"

    ${pkgs.glib}/bin/gsettings set "$BASE:$PATH_" \
      binding "<Super><Shift>s"
  '';
}
{ config, pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    grim
    slurp
    wl-clipboard
  ];

  programs.dconf.enable = true;

  # Apply GNOME shortcuts at user login via a one-shot systemd user service.
  # This runs as the 'pc' user so dconf schemas are available.
  systemd.user.services.gnome-custom-shortcuts = {
    description = "Set GNOME custom keyboard shortcuts";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = let
        script = pkgs.writeShellScript "set-gnome-shortcuts" ''
          SCHEMA="org.gnome.settings-daemon.plugins.media-keys"
          CPATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
          CSCHEMA="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$CPATH"
          SCREENSHOT_DIR="$HOME/Pictures/Screenshots"

          CMD="${pkgs.bash}/bin/bash -c '\
            mkdir -p ${"\${SCREENSHOT_DIR}"} && \
            F=${"\${SCREENSHOT_DIR}"}/\$(${pkgs.coreutils}/bin/date +%Y-%m-%d_%H-%M-%S).png && \
            ${pkgs.grim}/bin/grim -g \"\$(${pkgs.slurp}/bin/slurp)\" \$F && \
            ${pkgs.wl-clipboard}/bin/wl-copy < \$F'"

          ${pkgs.glib}/bin/gsettings set $SCHEMA custom-keybindings \
            "['$CPATH']"
          ${pkgs.glib}/bin/gsettings set $CSCHEMA name \
            "Screenshot region → clipboard + save"
          ${pkgs.glib}/bin/gsettings set $CSCHEMA command "$CMD"
          ${pkgs.glib}/bin/gsettings set $CSCHEMA binding "<Super><Shift>s"
        '';
      in "${script}";
    };
  };
}
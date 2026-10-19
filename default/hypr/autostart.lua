local md = require("default.hypr.helpers")

-- Finish initializing the keyring unlocked by greetd's PAM login. GNOME's
-- desktop autostart entries exclude Hyprland, so they cannot do this for us.
md.launch_on_start("gnome-keyring-daemon --start --components=pkcs11,secrets")
md.launch_on_start("strata-launch-shell")
md.launch_on_start("strata-greeter-theme-sync")
md.launch_on_start("strata-greeter-background-sync")
md.launch_on_start("fcitx5 -d --replace")
md.launch_on_start("wl-paste --watch cliphist store")
md.launch_on_start("udiskie --tray")
md.launch_on_start("hypridle")
md.on_start("systemctl --user start hyprsunset.service")
md.launch_on_start("strata-toggle-idle sync")
md.launch_on_start("strata-set-primary-monitor")
md.launch_on_start("strata-place-cursor-on-main")

return true

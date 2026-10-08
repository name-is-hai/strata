local md = require("default.hypr.helpers")

md.launch_on_start("strata-launch-shell")
md.launch_on_start("fcitx5 -d --replace")
md.launch_on_start("wl-paste --watch cliphist store")
md.launch_on_start("udiskie --tray")
md.launch_on_start("hypridle")
md.launch_on_start("strata-toggle-idle sync")

return true

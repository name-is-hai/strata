local md = require("default.hypr.helpers")

md.bind("SUPER + T", "Ghostty", md.launch("ghostty"))
md.bind("SUPER + Q", "Close window", hl.dsp.window.close())
md.bind("SUPER + F", "Nautilus", "strata-launch-nautilus")
md.bind("SUPER + B", "Browser", "strata-launch-browser")
md.bind("SUPER + code:61", "Application launcher", "strata-menu toggle")
md.bind("SUPER + ESCAPE", "System menu", "strata-menu toggle system")
md.bind("SUPER + K", "Keybinding help", "strata-menu-keybindings")
md.bind("SUPER + CTRL + T", "Activity monitor", md.launch("ghostty -e btop"))

return true

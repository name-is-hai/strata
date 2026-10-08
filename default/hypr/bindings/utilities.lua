local md = require("default.hypr.helpers")

md.bind("SUPER + L", "Lock", "strata-system-lock")
md.bind_toggle("SUPER + CTRL + I", "Toggle idle locking", "strata-toggle-idle")
md.bind_toggle("SUPER + CTRL + N", "Toggle night light", "strata-toggle-nightlight")
md.bind_toggle("SUPER + V", "Clipboard history", "strata-menu-clipboard")
md.bind_toggle("SUPER + CTRL + A", "Audio panel", "strata-shell shell toggle strata.audio")
md.bind_toggle("SUPER + CTRL + B", "Bluetooth panel", "strata-shell shell toggle strata.bluetooth")
md.bind_toggle("SUPER + CTRL + W", "Network panel", "strata-shell shell toggle strata.network")
md.bind_toggle("SUPER + CTRL + D", "Display panel", "strata-shell shell toggle strata.monitor")
md.bind_toggle("SUPER + CTRL + P", "Power panel", "strata-shell shell toggle strata.power")
md.bind_toggle("SUPER + CTRL + E", "Emoji picker", "strata-menu-emoji")
md.bind("SUPER + CTRL + comma", "Notification history", "strata-shell notifications showHistory")

return true

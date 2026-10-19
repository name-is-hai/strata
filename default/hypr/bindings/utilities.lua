local md = require("default.hypr.helpers")

md.bind("SUPER + L", "Lock", "strata-system-lock")
-- logind keeps its normal behavior until a custom button action is selected.
md.bind("XF86PowerOff", "Configured power button action", "strata-shell idle powerButton", { locked = true })
md.bind_toggle("SUPER + CTRL + I", "Toggle automatic sleep prevention", "strata-toggle-idle")
md.bind_toggle("SUPER + CTRL + N", "Toggle night light", "strata-toggle-nightlight")
md.bind_toggle("SUPER + V", "Clipboard history", "strata-menu-clipboard")
md.bind_toggle("SUPER + CTRL + M", "Media panel", "strata-shell shell toggle strata.media")
md.bind_toggle("SUPER + CTRL + A", "Audio panel", "strata-shell shell toggle strata.audio")
md.bind_toggle("SUPER + CTRL + B", "Bluetooth panel", "strata-shell shell toggle strata.bluetooth")
md.bind_toggle("SUPER + CTRL + W", "Network panel", "strata-shell shell toggle strata.network")
md.bind_toggle("SUPER + CTRL + D", "Display panel", "strata-shell shell toggle strata.monitor")
md.bind_toggle("SUPER + CTRL + P", "Power panel", "strata-shell shell toggle strata.power")
md.bind_toggle("SUPER + CTRL + E", "Emoji picker", "strata-menu-emoji")
md.bind("SUPER + CTRL + comma", "Notification history", "strata-shell notifications showHistory")
md.bind_toggle("SUPER + period", "Notification history", "strata-shell shell toggle strata.notifications")
-- Hyprland's `code:` binding uses XKB keycodes, which are eight higher than
-- Linux input keycodes: 37 is Left Ctrl and 105 is Right Ctrl. (29 is Y.)

return true

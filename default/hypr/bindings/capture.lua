local md = require("default.hypr.helpers")

md.bind("PRINT", "Screenshot", "strata-capture-screenshot region save")
md.bind("SUPER + SHIFT + S", "Screenshot to clipboard", "strata-capture-screenshot region copy")
md.bind_toggle("SUPER + SHIFT + R", "Toggle screen recording", "strata-toggle-screenrecording")
md.bind_toggle("SUPER + PRINT", "Toggle color picker", "pkill -x hyprpicker || hyprpicker -a")

return true

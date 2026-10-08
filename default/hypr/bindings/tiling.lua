local md = require("default.hypr.helpers")

md.bind("SUPER + SHIFT + T", "Toggle floating", hl.dsp.window.float({ action = "toggle" }))
md.bind("SUPER + SHIFT + F", "Fullscreen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
md.bind_toggle("SUPER + CTRL + F", "Tiled fullscreen", "strata-hyprland-window-tiled-fullscreen-toggle")
md.bind("SUPER + ALT + F", "Full width", hl.dsp.window.fullscreen({ mode = "maximized" }))
md.bind("SUPER + P", "Pseudotile", hl.dsp.window.pseudo())
md.bind("SUPER + J", "Toggle split", hl.dsp.layout("togglesplit"))

for _, direction in ipairs({ "left", "right", "up", "down" }) do
    md.bind("SUPER + " .. direction, "Focus " .. direction, hl.dsp.focus({ direction = direction }))
    md.bind("SUPER + SHIFT + " .. direction, "Swap window " .. direction, hl.dsp.window.swap({ direction = direction }))
end

md.bind("ALT + TAB", "Cycle windows forward", hl.dsp.window.cycle_next())
md.bind("ALT + SHIFT + TAB", "Cycle windows backward", hl.dsp.window.cycle_next({ next = false }))
md.bind("ALT + TAB", "Raise selected window", hl.dsp.window.bring_to_top())
md.bind("ALT + SHIFT + TAB", "Raise selected window", hl.dsp.window.bring_to_top())

md.bind("SUPER + mouse:272", "Move window", hl.dsp.window.drag(), { mouse = true })
md.bind("SUPER + mouse:273", "Resize window", hl.dsp.window.resize(), { mouse = true })

return true

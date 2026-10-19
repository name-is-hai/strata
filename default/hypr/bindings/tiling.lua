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

local altTabActive = false

local function switchPreview(direction)
    altTabActive = true
    hl.dispatch(hl.dsp.event("strata.window-switcher|" .. direction))
end

md.bind("ALT + TAB", "Next window preview", function() switchPreview("next") end, { repeating = true })
md.bind("ALT + SHIFT + TAB", "Previous window preview", function() switchPreview("previous") end, { repeating = true })

-- A modifier-only release bind can miss the release after the preview layer
-- takes keyboard focus. The raw input event is delivered independently of it.
hl.on("input.keyboard.key", function(keycode, _, state)
    if not altTabActive or state ~= 0 or (keycode ~= 64 and keycode ~= 108) then return end
    altTabActive = false
    hl.dispatch(hl.dsp.event("strata.window-switcher|commit"))
end)

md.bind("SUPER + mouse:272", "Move window", hl.dsp.window.drag(), { mouse = true })
md.bind("SUPER + mouse:273", "Resize window", hl.dsp.window.resize(), { mouse = true })

return true

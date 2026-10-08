local md = require("default.hypr.helpers")

for workspace = 1, 10 do
    local key = "code:" .. tostring(workspace + 9)
    md.bind("SUPER + " .. key, "Workspace " .. workspace, hl.dsp.focus({ workspace = tostring(workspace) }))
    md.bind("SUPER + SHIFT + " .. key, "Move to workspace " .. workspace,
        hl.dsp.window.move({ workspace = tostring(workspace) }))
    md.bind("SUPER + SHIFT + ALT + " .. key, "Move silently to workspace " .. workspace,
        hl.dsp.window.move({ workspace = tostring(workspace), follow = false }))
end

md.bind("SUPER + TAB", "Next workspace", hl.dsp.focus({ workspace = "e+1" }))
md.bind("SUPER + SHIFT + TAB", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))
md.bind("SUPER + CTRL + TAB", "Former workspace", hl.dsp.focus({ workspace = "previous" }))
md.bind("SUPER + mouse_down", "Next workspace", hl.dsp.focus({ workspace = "e+1" }))
md.bind("SUPER + mouse_up", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))

for _, direction in ipairs({ "left", "right", "up", "down" }) do
    md.bind("SUPER + SHIFT + ALT + " .. direction, "Move workspace " .. direction,
        hl.dsp.workspace.move({ monitor = direction }))
end

md.bind("SUPER + S", "Toggle scratchpad", hl.dsp.workspace.toggle_special("scratchpad"))
md.bind("SUPER + ALT + S", "Move to scratchpad",
    hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))

return true

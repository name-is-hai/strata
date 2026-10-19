local md = require("default.hypr.helpers")
local desktops = require("default.hypr.workspaces")

for workspace = 1, 10 do
    local key = "code:" .. tostring(workspace + 9)
    md.bind("SUPER + " .. key, "Workspace " .. workspace, function() desktops.select(workspace) end)
    md.bind("SUPER + SHIFT + " .. key, "Move to workspace " .. workspace,
        function() desktops.move(workspace, true) end)
    md.bind("SUPER + SHIFT + ALT + " .. key, "Move silently to workspace " .. workspace,
        function() desktops.move(workspace, false) end)
end

-- Cycle only the workspaces that belong to the monitor under focus. This
-- keeps each display's workspace loop independent on multi-monitor setups.
md.bind("SUPER + TAB", "Next workspace on this monitor", function() desktops.cycle(1) end)
md.bind("SUPER + SHIFT + TAB", "Previous workspace on this monitor", function() desktops.cycle(-1) end)
md.bind("SUPER + CTRL + TAB", "Former workspace on this monitor", function() desktops.previous() end)
md.bind("SUPER + mouse_down", "Next workspace on this monitor", function() desktops.cycle(1) end)
md.bind("SUPER + mouse_up", "Previous workspace on this monitor", function() desktops.cycle(-1) end)

for _, direction in ipairs({ "left", "right", "up", "down" }) do
    md.bind("SUPER + SHIFT + ALT + " .. direction, "Move workspace " .. direction,
        function() desktops.transfer_active(direction) end)
end

md.bind("SUPER + S", "Toggle scratchpad", hl.dsp.workspace.toggle_special("scratchpad"))
md.bind("SUPER + ALT + S", "Move to scratchpad",
    hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))

return true

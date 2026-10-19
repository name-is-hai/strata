-- Hardware-neutral monitor detection. An empty output is Hyprland's fallback
-- rule: every connected display without a more specific personal rule uses its
-- preferred mode, is placed automatically, and receives a PPI-based scale.
--
-- Add a named rule in ~/.config/hypr/monitors.lua only when a machine needs a
-- fixed position, refresh rate, scale, rotation, or mirroring arrangement.
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "auto",
})

-- Hyprland has no compositor-wide primary-output flag. Strata's Display
-- panel stores the Main output at (0, 0); use that choice as XWayland's
-- primary output on startup and after hotplug changes.
local function update_xwayland_primary()
    hl.exec_cmd("strata-set-primary-monitor")
end

for _, event in ipairs({ "hyprland.start", "monitor.added", "monitor.removed" }) do
    hl.on(event, update_xwayland_primary)
end

-- Keep one physical display usable even when the saved layout disables the
-- laptop panel. The helper restores the saved layout when an external returns.
for _, event in ipairs({ "hyprland.start", "monitor.layout_changed", "config.reloaded" }) do
    hl.on(event, function()
        hl.exec_cmd("strata-monitor-fallback")
    end)
end

-- Publish the applied layout at login and after personal config edits. Keep
-- hotplug-only fallback changes from replacing saved disabled-display choices.
for _, event in ipairs({ "hyprland.start", "config.reloaded" }) do
    hl.on(event, function()
        hl.exec_cmd("strata-greeter-monitors-sync")
    end)
end

return true

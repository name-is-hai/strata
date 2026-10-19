-- Strata owns the touchpad gestures. Keep these separate from input settings
-- so personal Hyprland Lua can replace individual gestures later.
-- Stage enables these callbacks only while its service is running. A config
-- reload starts disabled; the service reapplies its settings if enabled.
rawset(_G, "__strata_gestures_enabled", false)
local desktop_prefix = "strata-desktop-"

local function workspace_selector(workspace)
    if not workspace or workspace.special or workspace.id <= 0 then return nil end
    return tostring(workspace.id)
end

local function restore_desktop(workspace)
    local selector = workspace_selector(workspace)
    if not selector then return end
    local hidden = "special:" .. desktop_prefix .. selector
    local hidden_workspace = hl.get_workspace(hidden)
    local monitor = hidden_workspace and hidden_workspace.monitor
    local windows = hl.get_workspace_windows(hidden) or {}
    for _, window in ipairs(windows) do
        hl.dispatch(hl.dsp.window.move({ workspace = selector, follow = false, window = window }))
    end
    if monitor and #windows > 0 then
        hl.dispatch(hl.dsp.workspace.move({ workspace = selector, monitor = monitor }))
    end
end

local function toggle_desktop()
    local workspace = hl.get_active_workspace()
    local selector = workspace_selector(workspace)
    if not selector then return end
    local hidden = "special:" .. desktop_prefix .. selector
    if #(hl.get_workspace_windows(hidden) or {}) > 0 then
        restore_desktop(workspace)
        return
    end
    for _, window in ipairs(hl.get_workspace_windows(selector) or {}) do
        hl.dispatch(hl.dsp.window.move({ workspace = hidden, follow = false, window = window }))
    end
end

local three_finger_defaults = {
    left = "nextApp", right = "previousApp", up = "overview", down = "showDesktop",
}
rawset(_G, "__strata_three_finger_actions", three_finger_defaults)

local function three_finger_action(direction)
    if rawget(_G, "__strata_gestures_enabled") ~= true then return end
    local configured = rawget(_G, "__strata_three_finger_actions") or three_finger_defaults
    local action = configured[direction] or three_finger_defaults[direction]
    if action == "nextApp" then
        hl.dispatch(hl.dsp.global("strata.window-switcher:gesture-next"))
    elseif action == "previousApp" then
        hl.dispatch(hl.dsp.global("strata.window-switcher:gesture-previous"))
    elseif action == "overview" then
        hl.dispatch(hl.dsp.global("strata.window-switcher:overview"))
    elseif action == "showDesktop" then
        hl.dispatch(hl.dsp.event("strata.window-switcher|dismiss"))
        hl.dispatch(hl.dsp.event("strata.stage-control|dismiss"))
        toggle_desktop()
    elseif action == "stage" then
        hl.dispatch(hl.dsp.event("strata.stage-control|toggle"))
    elseif action == "appWindows" then
        hl.dispatch(hl.dsp.event("strata.stage-control|expose"))
    end
end

-- Keep the four existing actions unless the user changes one in Stage settings.
for _, direction in ipairs({ "left", "right", "up", "down" }) do
    local current = direction
    hl.gesture({ fingers = 3, direction = current, action = function() three_finger_action(current) end })
end

local desktops = require("default.hypr.workspaces")

hl.gesture({ fingers = 4, direction = "left", action = function()
    if rawget(_G, "__strata_gestures_enabled") == true then desktops.swipe(1) end
end })
hl.gesture({ fingers = 4, direction = "right", action = function()
    if rawget(_G, "__strata_gestures_enabled") == true then desktops.swipe(-1) end
end })

return true

-- Only the login wallpaper and form belong in this temporary compositor.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- Apply Main before creating the greeter surfaces, including closed-lid boots.
-- A disconnected Main does not disable the catch-all output above.
local main = os.getenv("STRATA_MAIN_MONITOR") or ""
if main:match("^[%w_.-]+$") then
    hl.monitor({ output = main, mode = "preferred", position = "0x0", scale = 1 })
end

-- Use a system-readable snapshot, never the user's executable/private config.
local disabled = {}
local policy = io.open("/etc/strata/disabled-monitors", "r")
if policy then
    for name in policy:lines() do
        if name:match("^[%w_.-]+$") then disabled[name] = true end
    end
    policy:close()
end

local applying = false
local function apply_monitor_policy()
    if applying or not next(disabled) then return end
    applying = true
    local allowed = false
    for _, monitor in ipairs(hl.get_monitors() or {}) do
        if monitor.name ~= "FALLBACK" and not disabled[monitor.name] then allowed = true; break end
    end
    for name in pairs(disabled) do
        if allowed then
            hl.monitor({ output = name, disabled = true })
        else
            -- An unplugged external screen must not leave login invisible.
            hl.monitor({ output = name, disabled = false, mode = "preferred", position = "auto", scale = 1 })
        end
    end
    applying = false
end

hl.on("monitor.added", apply_monitor_policy)
hl.on("monitor.removed", apply_monitor_policy)

hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        disable_watchdog_warning = true,
        disable_scale_notification = true,
        force_default_wallpaper = 0,
        background_color = 0x1e1e2e,
    },
    input = { kb_layout = "us", follow_mouse = 1 },
})

hl.on("hyprland.start", function()
    apply_monitor_policy()
    hl.exec_cmd("/usr/bin/strata-greeter-quickshell")
end)

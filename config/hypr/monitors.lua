-- Strata detects connected monitors automatically using the fallback in
-- /usr/share/strata/default/hypr/monitors.lua. Per-machine overrides belong
-- here only when a display needs a fixed arrangement.
local strata_monitor_scale = "auto"

-- Keep this catch-all rule so changing display scale in Strata's Display panel
-- is saved here and survives the next login. Named rules below take priority.
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = strata_monitor_scale,
})

-- Example:
-- hl.monitor({ output = "DP-1", mode = "2560x1440@144", position = "0x0", scale = 1 })

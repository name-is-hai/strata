hl.config({
    input = {
        kb_layout = "us",
        kb_options = "",
        repeat_rate = 40,
        repeat_delay = 600,
        numlock_by_default = true,
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            scroll_factor = 0.5,
        },
    },
    misc = {
        key_press_enables_dpms = true,
        mouse_move_enables_dpms = true,
    },
})

local config_home = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
pcall(dofile, config_home .. "/hypr/mouse.lua")

-- Inert until the Shortcut Guide publishes its local allowlist.
pcall(dofile, "/usr/share/strata/shell/plugins/services/shortcut-guide/bridge.lua")

return true

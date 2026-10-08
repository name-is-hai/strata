hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        col = {
            active_border = { colors = { "rgba(89b4faff)", "rgba(cba6f7ff)" }, angle = 45 },
            inactive_border = "rgba(45475aaa)",
        },
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding = 10,
        active_opacity = 1.0,
        inactive_opacity = 0.96,
        shadow = {
            enabled = true,
            range = 12,
            render_power = 3,
            color = 0xee11111b,
        },
        blur = {
            enabled = true,
            size = 4,
            passes = 2,
            special = true,
        },
    },
    animations = { enabled = true },
    dwindle = {
        preserve_split = true,
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        focus_on_activate = true,
    },
    cursor = { hide_on_key_press = true },
    binds = { hide_special_on_workspace_change = true },
})

hl.curve("smooth", { type = "bezier", points = { { 0.25, 0.1 }, { 0.25, 1.0 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "smooth" })
hl.animation({ leaf = "layers", enabled = true, speed = 5, bezier = "smooth" })
hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "smooth" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "smooth" })

-- The fullscreen command menu changes layer when it opens. Give that one
-- surface a fade rather than the default directional layer transition, so its
-- scrim and centered card appear in place instead of travelling from top-left.
hl.layer_rule({
    name = "strata-menu-fade",
    match = { namespace = "^strata-menu$" },
    animation = "fade",
})

return true

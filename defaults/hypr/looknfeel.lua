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
        rounding = 0,
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

-- Shortcut hints animate their live QML contents. Do not leave compositor
-- snapshots behind when capture hands off to the native selector's chrome.
hl.layer_rule({
    name = "strata-shortcut-hints-live",
    match = { namespace = "^strata-shortcut-(guide|promoter)$" },
    no_anim = true,
    animation = "none",
})

-- Strata Snip captures the frame before opening this layer. Keep its picker in
-- place so its frozen image never slides in from a screen edge.
hl.layer_rule({
    name = "strata-snip-freeze",
    match = { namespace = "^strata-snip$" },
    no_anim = true,
    animation = "none",
})

-- The enlarged pointer shares the overlay layer with panels. Hyprland sorts
-- layer surfaces by descending reservation order and paints them in that
-- order, so a negative value keeps this input-transparent cursor above panels
-- even when a panel is mapped later. Its motion is animated by QML already.
hl.layer_rule({
    name = "strata-wiggle-cursor",
    match = { namespace = "^strata-wiggle-cursor$" },
    order = -1000,
    no_anim = true,
    animation = "none",
})

return true

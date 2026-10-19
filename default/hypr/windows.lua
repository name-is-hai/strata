hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

hl.window_rule({
    name = "float-file-dialogs",
    match = { title = "^(Open File|Save File|Choose Files?)$" },
    float = true,
})

hl.window_rule({
    name = "picture-in-picture",
    match = { title = "^(Picture-in-Picture)$" },
    float = true,
    pin = true,
})

-- The recording preview is a borderless video surface, not a tiled player.
hl.window_rule({
    name = "strata-webcam-overlay",
    match = { class = "^WebcamOverlay-(small|medium|large)$", title = "^WebcamOverlay$" },
    float = true,
    pin = true,
    no_focus = true,
})

-- Theme installation and other Strata presentation commands launch Ghostty
-- with this app ID. Keep that short-lived workflow out of the tiling layout.
hl.window_rule({
    name = "strata-presentation-terminal",
    -- Hyprland matches PCRE-style regular expressions here, not Lua patterns.
    match = { class = "^org[.]strata[.]terminal$" },
    float = true,
    center = true,
})

hl.window_rule({
    name = "strata-shortcut-guide-settings",
    match = { title = "^Strata Shortcut Guide$" },
    float = true,
    center = true,
})

return true

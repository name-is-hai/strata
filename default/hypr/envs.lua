hl.env("XCURSOR_THEME", "Win11OSX")
hl.env("XCURSOR_SIZE", "26")
hl.env("HYPRCURSOR_THEME", "Win11OSX")
hl.env("HYPRCURSOR_SIZE", "26")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland,x11")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

hl.config({
    xwayland = { force_zero_scaling = true },
    ecosystem = { no_update_news = true },
})

return true

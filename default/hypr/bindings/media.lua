local md = require("default.hypr.helpers")

md.bind("XF86AudioRaiseVolume", "Volume up", "strata-audio-output-volume raise",
    { locked = true, repeating = true })
md.bind("XF86AudioLowerVolume", "Volume down", "strata-audio-output-volume lower",
    { locked = true, repeating = true })
md.bind("XF86AudioMute", "Mute audio", "strata-audio-output-volume mute-toggle", { locked = true })
md.bind("XF86AudioMicMute", "Mute microphone", "strata-audio-input-mute", { locked = true })
md.bind("XF86AudioPlay", "Play or pause", "strata-shell media playPause", { locked = true })
md.bind("XF86AudioPause", "Play or pause", "strata-shell media playPause", { locked = true })
md.bind("XF86AudioNext", "Next track", "strata-shell media next", { locked = true })
md.bind("XF86AudioPrev", "Previous track", "strata-shell media previous", { locked = true })
md.bind("XF86MonBrightnessUp", "Brightness up", "strata-brightness-display +5%", { locked = true, repeating = true })
md.bind("XF86MonBrightnessDown", "Brightness down", "strata-brightness-display 5%-", { locked = true, repeating = true })

return true

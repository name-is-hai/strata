// Strata's Display settings place the Main output at the layout origin.
function formScreenName(screens, remoteDesktopActive) {
  if (remoteDesktopActive) {
    for (var remote = 0; remote < screens.length; remote++) {
      var candidate = screens[remote]
      if (candidate && candidate.name && candidate.name.indexOf("hypr-rdp-") === 0
          && candidate.width > 0 && candidate.height > 0) return candidate.name
    }
  }
  var fallback = ""
  for (var i = 0; i < screens.length; i++) {
    var screen = screens[i]
    if (!screen || !screen.name || screen.width <= 0 || screen.height <= 0) continue
    if (!fallback) fallback = screen.name
    if (screen.x === 0 && screen.y === 0) return screen.name
  }
  return fallback
}

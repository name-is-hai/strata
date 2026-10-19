// Strata's Display settings place the Main output at the layout origin.
function formScreenName(screens) {
  var fallback = ""
  for (var i = 0; i < screens.length; i++) {
    var screen = screens[i]
    if (!screen || !screen.name || screen.width <= 0 || screen.height <= 0) continue
    if (!fallback) fallback = screen.name
    if (screen.x === 0 && screen.y === 0) return screen.name
  }
  return fallback
}

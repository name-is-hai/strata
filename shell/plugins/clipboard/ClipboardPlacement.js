// Hyprland's batch reply contains consecutive JSON documents.
function parsePosition(raw) {
  try {
    var split = raw.indexOf("[")
    var cursor = JSON.parse(raw.slice(0, split))
    var monitors = JSON.parse(raw.slice(split))
    for (var i = 0; i < monitors.length; i++) {
      var monitor = monitors[i]
      if (monitor.disabled) continue
      var rotated = Number(monitor.transform || 0) % 2 !== 0
      var scale = Number(monitor.scale) || 1
      var width = (rotated ? monitor.height : monitor.width) / scale
      var height = (rotated ? monitor.width : monitor.height) / scale
      if (cursor.x >= monitor.x && cursor.x < monitor.x + width
          && cursor.y >= monitor.y && cursor.y < monitor.y + height)
        return { name: monitor.name, x: cursor.x - monitor.x, y: cursor.y - monitor.y }
    }
  } catch (error) {}
  return null
}

function axisPosition(cursor, extent, available, margin, gap) {
  var desired = cursor + gap
  if (desired + extent > available - margin) desired = cursor - gap - extent
  return Math.max(margin, Math.min(desired, available - extent - margin))
}

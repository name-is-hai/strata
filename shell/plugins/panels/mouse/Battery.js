function warnings(devices, previous) {
  var next = Object.assign({}, previous || {})
  var notifications = []
  for (var i = 0; i < devices.length; i++) {
    var device = devices[i]
    if (device.percentage === null || device.percentage === undefined) continue
    var level = Number(device.percentage)
    if (!isFinite(level) || level < 0 || level > 100) continue
    if (device.charging === true || level > 25) { delete next[device.id]; continue }
    var stage = level <= 5 ? 2 : level <= 20 ? 1 : 0
    if (stage > Number(next[device.id] || 0)) {
      next[device.id] = stage
      notifications.push({ name: device.name, level: Math.round(level), critical: stage === 2 })
    }
  }
  return { state: next, notifications: notifications }
}

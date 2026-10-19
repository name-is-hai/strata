function normalizeAddress(value) {
  var address = String(value || "").toLowerCase()
  if (address && address.indexOf("0x") !== 0) address = "0x" + address
  return /^0x[0-9a-f]+$/.test(address) ? address : ""
}

function snapshotWindows(clients, toplevels) {
  if (!Array.isArray(clients)) return []
  var byAddress = {}
  // Quickshell's ObjectModel.values is array-like, but not a JS Array.
  var tops = toplevels && toplevels.length ? toplevels : []
  for (var i = 0; i < tops.length; i++) {
    var top = tops[i]
    var address = normalizeAddress(top && top.address)
    if (address) byAddress[address] = top
  }

  var rows = []
  for (var j = 0; j < clients.length; j++) {
    var client = clients[j]
    if (!client || client.mapped === false || client.hidden === true) continue
    var workspace = Number(client.workspace ? client.workspace.id : -1)
    if (workspace <= 0) continue
    var key = normalizeAddress(client.address)
    if (!key) continue
    var topLevel = byAddress[key] || null
    var wayland = topLevel ? topLevel.wayland || null : null
    var appClass = String(client.class || client.initialClass || (wayland ? wayland.appId : "") || "Application")
    var history = Number(client.focusHistoryID)
    if (!Number.isFinite(history) || history < 0) history = 2147483647
    rows.push({
      address: key,
      appClass: appClass,
      title: String(client.title || (topLevel ? topLevel.title : "") || appClass),
      focusHistoryId: history,
      wayland: wayland
    })
  }
  rows.sort(function(a, b) { return a.focusHistoryId - b.focusHistoryId })
  return rows
}

function selectedIndex(steps, count) {
  if (count <= 0) return -1
  return ((steps % count) + count) % count
}

if (typeof module !== "undefined") module.exports = {
  normalizeAddress: normalizeAddress,
  snapshotWindows: snapshotWindows,
  selectedIndex: selectedIndex
}

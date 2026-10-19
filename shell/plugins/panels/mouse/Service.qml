import QtQuick
import Quickshell
import Quickshell.Io
import "Battery.js" as Battery

Item {
  id: root
  property var shell: null
  property var devices: []
  property string deviceSignature: ""
  readonly property bool lowBattery: devices.some(function(device) {
    return device.percentage !== null && device.percentage <= 20 && device.charging !== true
  })
  PersistentProperties {
    id: persisted
    reloadableId: "strata-mouse-battery"
    property var warned: ({})
  }
  function refresh() { if (!query.running) query.running = true }
  function update(raw) {
    try {
      var next = JSON.parse(raw)
      if (!Array.isArray(next)) return
      var signature = next.map(function(device) { return device.id }).sort().join("\n")
      if (signature !== deviceSignature) {
        deviceSignature = signature
        syncTouchpads.running = true
      }
      devices = next
      var result = Battery.warnings(next, persisted.warned)
      persisted.warned = result.state
      result.notifications.forEach(function(warning) {
        Quickshell.execDetached(["strata-notification-send", "--app-name", "Mouse",
          "-g", "󰍽", "-u", warning.critical ? "critical" : "normal",
          warning.critical ? "Mouse battery critical" : "Mouse battery low",
          warning.name + " · " + warning.level + "% remaining",
          "--exec", "strata-shell", "shell", "summon", "strata.mouse"])
      })
    } catch (error) { console.warn("mouse: could not read device battery data") }
  }
  Process { id: syncTouchpads; command: ["strata-mouse-settings", "sync-touchpads"] }
  Process {
    id: query
    command: ["strata-mouse-devices"]
    stdout: StdioCollector { onStreamFinished: root.update(text) }
  }
  Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
}

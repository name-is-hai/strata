import QtQuick
import Quickshell.Io
import qs.Ui

// Persistent status/control for the Strata hotspot. A click opens the Network
// panel, whose Hotspot section owns start/stop and client access rules.
BarIndicator {
  id: root

  property bool hotspotActive: false
  property int clientCount: 0

  active: hotspotActive
  alwaysVisible: true
  activeText: "󰖩"
  inactiveText: "󰖩"
  activeTooltipText: clientCount === 1
    ? "Hotspot · 1 device connected"
    : "Hotspot · " + clientCount + " devices connected"
  inactiveTooltipText: "Set up Wi-Fi hotspot"

  function refresh() {
    if (!root.bar || statusProc.running) return
    statusProc.command = ["strata-network-hotspot", "status"]
    statusProc.running = true
  }

  Component.onCompleted: refresh()
  onBarChanged: refresh()

  Connections {
    target: root.indicatorHost
    ignoreUnknownSignals: true
    function onRefreshRequested() { root.refresh() }
  }

  Timer {
    interval: 2500
    repeat: true
    running: root.bar !== null
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    stdout: StdioCollector { id: statusOutput; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0 || !/^active\t1$/m.test(String(statusOutput.text || ""))) {
        root.hotspotActive = false
        root.clientCount = 0
        return
      }
      root.hotspotActive = true
      if (!clientsProc.running) clientsProc.running = true
    }
  }

  Process {
    id: clientsProc
    command: ["strata-network-hotspot", "clients"]
    stdout: StdioCollector { id: clientsOutput; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) { root.clientCount = 0; return }
      var matches = String(clientsOutput.text || "").match(/^client=/gm)
      root.clientCount = matches ? matches.length : 0
    }
  }

  onPressed: function() {
    if (root.bar) root.bar.run("strata-shell shell toggle strata.network")
  }
}

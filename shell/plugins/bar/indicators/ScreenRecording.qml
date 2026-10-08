import QtQuick
import Quickshell.Io
import qs.Ui

BarIndicator {
  id: root

  property string captureState: "idle"
  readonly property bool recording: captureState === "recording"
  readonly property bool sharing: captureState === "sharing"

  active: recording || sharing
  activeText: recording ? "󰻂" : "󰖟"
  inactiveText: "󰻂"
  activeTooltipText: recording ? "Stop recording" : "Screen sharing is active"
  inactiveTooltipText: "Screen Recording"

  function refresh() {
    if (!root.bar || statusProc.running) return
    statusProc.command = ["strata-screen-capture-status"]
    statusProc.running = true
  }

  onBarChanged: refresh()
  Component.onCompleted: refresh()

  Connections {
    target: root.indicatorHost
    ignoreUnknownSignals: true
    function onRefreshRequested() { root.refresh() }
  }

  Timer {
    interval: 2000
    running: root.bar !== null
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    stdout: SplitParser {
      onRead: function(line) { root.captureState = String(line).trim() }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.captureState = "idle"
    }
  }

  onPressed: function() {
    if (root.bar) {
      root.bar.run(root.recording ? "strata-capture-screenrecording --stop-recording" : "strata-menu summon trigger.capture.screenrecord")
    }
  }
}

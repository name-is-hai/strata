import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

BarIndicator {
  id: root

  property string captureState: "idle"
  readonly property var privacy: bar && bar.shell ? bar.shell.firstPartyServiceFor("strata.privacy") : null
  readonly property bool recording: privacy ? privacy.recording : captureState === "recording"
  readonly property bool sharing: privacy ? privacy.screens.length > 0 : captureState === "sharing"

  active: recording || sharing
  useActiveColor: root.recording || root.sharing
  activeColor: Color.urgent
  activeText: recording ? "󰻂" : "󰍹"
  inactiveText: "󰻂"
  activeTooltipText: (recording ? "Screen recording — click to stop" : "Screen sharing is active")
    + (privacy ? "\n" + privacy.describe("screen") : "")
  inactiveTooltipText: "Screen Recording"

  function refresh() {
    if (!root.bar || root.privacy || statusProc.running) return
    statusProc.command = ["strata-screen-capture-status"]
    statusProc.running = true
  }

  onBarChanged: refresh()
  onPrivacyChanged: refresh()
  Component.onCompleted: refresh()

  Connections {
    target: root.indicatorHost
    ignoreUnknownSignals: true
    function onRefreshRequested() { root.refresh() }
  }

  Timer {
    interval: 2000
    running: root.bar !== null && !root.privacy
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

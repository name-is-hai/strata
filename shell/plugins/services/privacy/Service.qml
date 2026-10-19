import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  property var shell: null
  property var state: ({ready:false, camera:[], microphone:[], screen:[], recording:false})
  property bool settled: false
  readonly property var cameras: state.camera || []
  readonly property var microphones: state.microphone || []
  readonly property var screens: state.screen || []
  readonly property bool recording: state.recording === true
  readonly property bool unavailable: settled && state.ready !== true
  function status() { return JSON.stringify(root.state) }
  function describe(kind) {
    var rows = state[kind] || []
    return rows.map(function(row) { return row.app + (row.muted ? " (muted)" : "") }).join("\n")
  }
  Process {
    id: watcher
    command: ["setpriv", "--pdeathsig", "TERM", "python3", "-u",
      Quickshell.env("STRATA_PATH") + "/shell/plugins/services/privacy/monitor.py"]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var next = JSON.parse(line)
          if (!Array.isArray(next.camera) || !Array.isArray(next.microphone) || !Array.isArray(next.screen)) return
          root.state = next
          if (next.ready === true) root.settled = true
        } catch (error) {}
      }
    }
    onExited: {
      root.state = {ready:false, camera:[], microphone:[], screen:[], recording:false}
      retry.restart()
    }
  }
  Timer { interval:5000; running:true; onTriggered: root.settled = true }
  Timer { id:retry; interval:2000; onTriggered: watcher.running = true }
}

import QtQuick
import Quickshell.Io
import qs.Commons

Item {
  id: root
  property var shell: null
  property var manifest: null
  readonly property string moduleName: "strata.system-update"
  property var statusData: ({available:false, updates:[], error:""})
  readonly property bool updateAvailable: statusData.available === true
  readonly property bool checking: checker.running
  readonly property string summary: {
    var updates = statusData.updates || []
    var lines = ["Strata updates available"]
    for (var i=0; i<updates.length; ++i) lines.push(updates[i].name + " · " + updates[i].version)
    if (statusData.error) lines.push("Last check failed; showing the previous result")
    return lines.join("\n")
  }
  function refresh(force) {
    if (checker.running) return
    checker.command = force === true ? ["strata-update-check", "--refresh", "--notify"] : ["strata-update-check", "--notify"]
    checker.running = true
  }
  Process {
    id: checker
    stdout: StdioCollector { id: output; waitForEnd: true }
    onExited: {
      try {
        var next = JSON.parse(output.text)
        if (typeof next.available === "boolean" && Array.isArray(next.updates)) root.statusData = next
      } catch (error) { console.warn("Strata update check returned invalid status") }
    }
  }
  Timer { interval:15000; running:true; onTriggered:root.refresh(false) }
  Timer { interval:21600000; running:true; repeat:true; onTriggered:root.refresh(false) }
  ShellIpc {
    target: "strata.system-update"
    function refresh(): string { root.refresh(true); return "ok" }
    function status(): string { return JSON.stringify(root.statusData) }
  }
}

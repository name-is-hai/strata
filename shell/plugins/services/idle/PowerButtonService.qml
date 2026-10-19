import QtQuick
import Quickshell.Io

// Hyprland delivers the key; logind's low-level inhibitor prevents a second
// action. Closing the shell releases the inhibitor and restores system handling.
Item {
  id: root
  property var shell: null
  property string action: "system"
  property bool hibernateAvailable: false
  property bool hibernateAfterSleep: false
  property bool ready: false
  property bool retryPending: false
  readonly property bool managed: action !== "system"
  signal errorOccurred(string message)

  function ensureInhibitor() {
    if (managed && !inhibitor.running && !retryPending) inhibitor.running = true
    else if (!managed && inhibitor.running) inhibitor.running = false
  }

  function press() {
    if (!managed) return "system"
    if (!ready) {
      errorOccurred("Power button handling is not ready")
      return "not-ready"
    }
    if (action === "nothing") return "ignored"
    if (powerProcess.running) return "busy"
    if (action === "hibernate" && !hibernateAvailable) {
      errorOccurred("Hibernate is not available on this computer")
      return "unavailable"
    }
    if (action === "menu") {
      var lock = shell ? shell.firstPartyServiceFor("strata.lock") : null
      if (lock && lock.locked) {
        errorOccurred("Unlock to open the power menu")
        return "locked"
      }
      powerProcess.command = ["strata-menu", "summon", "system"]
    } else if (action === "lock") {
      powerProcess.command = ["strata-system-lock"]
    } else if (action === "sleep") {
      powerProcess.command = hibernateAfterSleep
        ? ["strata-idle-settings", "sleep", "--hibernate-after"]
        : ["systemctl", "--no-ask-password", "suspend"]
    } else if (action === "hibernate") {
      powerProcess.command = ["systemctl", "--no-ask-password", "hibernate"]
    } else if (action === "shutdown") {
      powerProcess.command = ["systemctl", "--no-ask-password", "poweroff"]
    } else {
      return "invalid-action"
    }
    powerProcess.running = true
    return "ok"
  }

  onManagedChanged: ensureInhibitor()
  Component.onCompleted: ensureInhibitor()

  Process {
    id: inhibitor
    command: ["systemd-inhibit", "--what=handle-power-key", "--who=Strata",
      "--why=Handle the configured power-button action", "--mode=block",
      "bash", "-c", "printf 'ready\\n'; exec gdbus monitor --system --dest org.freedesktop.login1 --object-path /org/freedesktop/login1"]
    stdout: SplitParser {
      onRead: function(line) { if (line === "ready") root.ready = true }
    }
    onExited: function(code) {
      root.ready = false
      if (root.managed) {
        root.retryPending = true
        retryTimer.restart()
        if (code !== 0) root.errorOccurred("Could not take control of the power button")
      }
    }
  }

  Timer {
    id: retryTimer
    interval: 2000
    onTriggered: { root.retryPending = false; root.ensureInhibitor() }
  }

  Process {
    id: powerProcess
    onExited: function(code) {
      if (code !== 0) root.errorOccurred("Power button action failed")
    }
  }
}

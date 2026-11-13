import QtQuick
import Quickshell
import Quickshell.Io

// Adapted from lgse/sandman (MIT); see LICENSE.sandman. Lid handling is
// independent from Strata's idle cycle. For a
// custom action, this service takes a low-level logind inhibitor and responds to
// lid state changes itself. Selecting "system" releases the inhibitor and puts
// logind back in charge.
Item {
  id: root

  property string action: "system"
  property bool hibernateAfterSleep: false
  property string helperPath: "strata-idle-settings"
  property bool present: false
  property bool closed: false
  property bool stateKnown: false
  property string hibernateCapability: "unknown"
  property string suspendThenHibernateCapability: "unknown"
  property string internalDisplay: ""
  property bool displayOff: false
  property bool displayWakePending: false
  property string pendingDisplayAction: ""
  property string powerAction: ""
  property bool monitorRestarting: false
  property bool clamshellSyncPending: false
  property int connectedScreenCount: Quickshell.screens.length

  readonly property bool managed: action !== "system"
  // Intercept only logind's lid handling. A global sleep inhibitor would also
  // block Strata's independent idle-sleep timer in Do nothing/Display off modes.
  readonly property string inhibitorWhat: "handle-lid-switch"
  readonly property bool hibernateAvailable: hibernateCapability === "yes"
  readonly property bool suspendThenHibernateAvailable: suspendThenHibernateCapability === "yes"

  signal errorOccurred(string message)

  function scheduleStateQuery() {
    stateQueryDebounce.restart()
  }

  function applyState(value) {
    var next = Boolean(value)
    if (!root.stateKnown) {
      root.closed = next
      root.stateKnown = true
      root.syncClamshell()
      return
    }
    if (root.closed === next) return
    root.closed = next
    if (next) handleClosed()
    else handleOpened()
  }

  function handleClosed() {
    root.syncClamshell()
    if (!root.managed) return
    if (root.action === "display") turnDisplayOff()
    else if (root.action === "sleep") requestPowerAction("suspend")
    else if (root.action === "hibernate") requestPowerAction("hibernate")
  }

  function handleOpened() {
    root.syncClamshell()
    if (root.displayOff) turnDisplayOn()
  }

  function syncClamshell() {
    if (!root.present || !root.stateKnown) return
    if (clamshellProcess.running) {
      root.clamshellSyncPending = true
      return
    }
    root.clamshellSyncPending = false
    clamshellProcess.command = ["strata-hyprland-monitor-clamshell", root.closed ? "closed" : "open"]
    clamshellProcess.running = true
  }

  function clamshellFinished(exitCode) {
    if (exitCode !== 0) root.errorOccurred("Could not update the laptop display for the lid state")
    if (root.clamshellSyncPending) Qt.callLater(root.syncClamshell)
  }

  function turnDisplayOff() {
    if (root.displayOff || displayOffProcess.running || activeDisplayProcess.running) return
    if (!root.internalDisplay) {
      root.errorOccurred("Could not find the laptop's internal display")
      return
    }
    root.displayOff = true
    root.displayWakePending = false
    queryActiveDisplay("off")
  }

  function turnDisplayOn() {
    if (!root.displayOff) return
    if (displayOffProcess.running || activeDisplayProcess.running) {
      root.displayWakePending = true
      return
    }
    root.displayOff = false
    root.displayWakePending = false
    if (!root.internalDisplay || displayOnProcess.running) return
    queryActiveDisplay("enable")
  }

  // hl.dsp.dpms falls back to every enabled monitor when its selector matches
  // nothing, which happens once the clamshell configuration has disabled the
  // internal output on the same lid close.
  function queryActiveDisplay(action) {
    root.pendingDisplayAction = action
    activeDisplayProcess.running = true
  }

  function dispatchDisplayAction(active) {
    var action = root.pendingDisplayAction
    root.pendingDisplayAction = ""
    if (action === "off") {
      if (active === false) {
        // Disabled elsewhere, so the lid open has nothing to restore.
        root.displayOff = false
        root.displayWakePending = false
        return
      }
      displayOffProcess.command = ["hyprctl", "dispatch", "hl.dsp.dpms({ action = \"off\", monitor = \"" + root.internalDisplay + "\" })"]
      displayOffProcess.running = true
    } else if (action === "enable") {
      if (active === false) return
      displayOnProcess.command = ["hyprctl", "dispatch", "hl.dsp.dpms({ action = \"enable\", monitor = \"" + root.internalDisplay + "\" })"]
      displayOnProcess.running = true
    }
  }

  function reapplyAfterGlobalDisplayOn() {
    if (!root.closed || !root.displayOff) return
    root.displayOff = false
    root.turnDisplayOff()
  }

  function requestPowerAction(requestedAction) {
    if (powerProcess.running) return
    if (requestedAction === "hibernate" && !root.hibernateAvailable) {
      root.errorOccurred("Hibernate is not available on this computer")
      return
    }
    root.powerAction = requestedAction
    var effectiveAction = requestedAction === "suspend" && root.hibernateAfterSleep
      ? "suspend-then-hibernate" : requestedAction
    if (effectiveAction === "suspend-then-hibernate" && !root.suspendThenHibernateAvailable) {
      root.errorOccurred("Suspend then hibernate is not available on this computer")
      return
    }
    // The helper falls back to plain suspend while an eGPU is attached.
    powerProcess.command = effectiveAction === "suspend-then-hibernate"
      ? [root.helperPath, "sleep", "--hibernate-after"]
      : ["systemctl", effectiveAction]
    powerProcess.running = true
  }

  function ensureMonitorRunning() {
    if (root.present) {
      if (!monitorProcess.running && !root.monitorRestarting) monitorProcess.running = true
    } else if (monitorProcess.running) {
      monitorProcess.running = false
    }
  }

  function restartMonitor() {
    if (!monitorProcess.running) {
      ensureMonitorRunning()
      return
    }
    root.monitorRestarting = true
    monitorProcess.running = false
    monitorRestartTimer.restart()
  }

  onActionChanged: {
    if (root.displayOff && root.action !== "display") root.turnDisplayOn()
    root.scheduleStateQuery()
    if (root.stateKnown && root.closed) Qt.callLater(root.handleClosed)
  }

  onInhibitorWhatChanged: restartMonitor()
  onManagedChanged: restartMonitor()
  onPresentChanged: { ensureMonitorRunning(); syncClamshell() }
  onConnectedScreenCountChanged: syncClamshell()
  Component.onCompleted: scheduleStateQuery()

  FileView {
    path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/strata/display-settings.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.syncClamshell()
  }

  Process {
    id: capabilityProcess
    command: ["busctl", "get-property", "org.freedesktop.UPower", "/org/freedesktop/UPower", "org.freedesktop.UPower", "LidIsPresent"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.present = /b\s+true/.test(String(text))
        root.scheduleStateQuery()
      }
    }
    Component.onCompleted: running = true
  }

  Process {
    id: hibernateCapabilityProcess
    command: ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "CanHibernate"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var match = String(text).match(/"([^"]+)"/)
        root.hibernateCapability = match ? match[1] : "unknown"
      }
    }
    Component.onCompleted: running = true
  }

  Process {
    id: suspendThenHibernateCapabilityProcess
    command: ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "CanSuspendThenHibernate"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var match = String(text).match(/"([^"]+)"/)
        root.suspendThenHibernateCapability = match ? match[1] : "unknown"
      }
    }
    Component.onCompleted: running = true
  }

  Process {
    id: internalDisplayProcess
    command: ["hyprctl", "monitors", "all", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var monitors = JSON.parse(String(text))
          for (var i = 0; i < monitors.length; i++) {
            var name = String(monitors[i].name || "")
            if (/^(eDP|LVDS|DSI)/i.test(name)) {
              root.internalDisplay = name
              break
            }
          }
        } catch (error) {
        }
      }
    }
    Component.onCompleted: running = true
  }

  Timer {
    id: stateQueryDebounce
    interval: 25
    repeat: false
    onTriggered: if (!stateQueryProcess.running) stateQueryProcess.running = true
  }

  Process {
    id: stateQueryProcess
    command: ["busctl", "get-property", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "LidClosed"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyState(/b\s+true/.test(String(text)))
    }
  }

  Timer {
    id: monitorRestartTimer
    interval: 50
    repeat: false
    onTriggered: {
      root.monitorRestarting = false
      root.ensureMonitorRunning()
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: true
    onTriggered: root.ensureMonitorRunning()
  }

  Process {
    id: monitorProcess
    // Observe lid events even when logind owns the power action. Only custom
    // actions take an inhibitor; monitoring alone must not change sleep policy.
    command: (root.managed
      ? ["systemd-inhibit", "--what=" + root.inhibitorWhat, "--who=Strata", "--why=Handle the configured lid-close action", "--mode=block"] : [])
      .concat(["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1"])
    stdout: SplitParser {
      onRead: function(line) {
        if (String(line).indexOf("LidClosed") >= 0) root.scheduleStateQuery()
      }
    }
    onExited: function(exitCode) {
      if (!root.monitorRestarting && root.present && exitCode !== 0)
        root.errorOccurred("Could not monitor laptop lid events")
      if (!root.monitorRestarting) Qt.callLater(root.ensureMonitorRunning)
    }
  }

  Process {
    id: clamshellProcess
    onExited: function(exitCode) { root.clamshellFinished(exitCode) }
  }

  Process {
    id: activeDisplayProcess
    command: ["hyprctl", "monitors", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        // Unparsable output stays null so the dispatch still reports failure.
        var active = null
        try {
          var monitors = JSON.parse(String(text))
          active = false
          for (var i = 0; i < monitors.length; i++) {
            if (String(monitors[i].name || "") === root.internalDisplay && monitors[i].disabled !== true) active = true
          }
        } catch (error) {
        }
        root.dispatchDisplayAction(active)
      }
    }
  }

  Process {
    id: displayOffProcess
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.displayOff = false
        root.errorOccurred("Could not turn the laptop display off")
      }
      if (root.displayWakePending) root.turnDisplayOn()
    }
  }

  Process { id: displayOnProcess }

  Process {
    id: powerProcess
    onExited: function(exitCode) {
      var completedAction = root.powerAction
      root.powerAction = ""
      if (exitCode !== 0)
        root.errorOccurred(completedAction === "hibernate"
          ? "Could not hibernate the computer"
          : root.hibernateAfterSleep
            ? "Could not suspend then hibernate the computer"
            : "Could not suspend the computer")
    }
  }
}

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

Item {
  id: root

  // Injected by strata-shell (the first-party service loader).
  property var shell: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string stayAwakeStateDir: home + "/.local/state/strata/indicators"
  readonly property string stayAwakeStatePath: stayAwakeStateDir + "/stay-awake"
  readonly property int defaultLockSeconds: 300
  readonly property var idleConfig: shell && shell.shellConfig && shell.shellConfig.idle
    ? shell.shellConfig.idle : (shell && shell.idleConfig ? shell.idleConfig : ({}))
  readonly property int lockTimeoutSeconds: secondsFromConfig(idleConfig.lock, defaultLockSeconds)
  readonly property bool lockEnabled: lockTimeoutSeconds > 0
  readonly property bool idleEnabled: stayAwakeStateLoaded && !stayAwake

  property bool stayAwake: false
  property bool stayAwakeStateLoaded: false
  property bool idledThisCycle: false
  property string lastEvent: "starting"
  property string lastEventAt: ""

  function secondsFromConfig(value, fallback) {
    var number = Number(value)
    if (!isFinite(number) || number < 0) return fallback
    return Math.floor(number)
  }

  function nowIso() {
    return new Date().toISOString()
  }

  function logEvent(event, details) {
    var suffix = details === undefined || details === null || details === "" ? "" : ": " + String(details)
    root.lastEventAt = nowIso()
    root.lastEvent = event + suffix
    console.log("strata idle " + root.lastEventAt + " " + root.lastEvent)
  }

  function runProcess(process, label, command) {
    if (process.running) {
      logEvent("process-skip", label + " already running")
      return false
    }
    logEvent("process-start", label + " " + command)
    process.command = ["bash", "-lc", command]
    process.running = true
    return true
  }

  function lockSystem(reason) {
    if (root.idledThisCycle) return
    root.idledThisCycle = true
    logEvent("lock-system", reason || "requested")
    runProcess(lockProcess, "lock", "strata-system-lock")
  }

  function endIdleCycle(reason) {
    if (!root.idledThisCycle) return
    logEvent("idle-cycle-end", reason || "activity")
    root.idledThisCycle = false
    runProcess(wakeProcess, "wake", "strata-system-wake")
  }

  function handleIdleChanged() {
    logEvent("idle-monitor", idleMonitor.isIdle ? "idle" : "active")
    if (!root.lockEnabled) return
    if (idleMonitor.isIdle) lockSystem("lock-timeout")
    else endIdleCycle("activity")
  }

  function statusJson() {
    return JSON.stringify({
      enabled: root.idleEnabled,
      stayAwake: root.stayAwake,
      stayAwakeStateLoaded: root.stayAwakeStateLoaded,
      stayAwakeStatePath: root.stayAwakeStatePath,
      idle: idleMonitor.isIdle,
      inIdleCycle: root.idledThisCycle,
      lock: root.lockTimeoutSeconds,
      processes: {
        lock: lockProcess.running,
        wake: wakeProcess.running
      },
      lastEvent: root.lastEvent,
      lastEventAt: root.lastEventAt
    })
  }

  function refreshStayAwakeState() {
    if (!stayAwakeStateProbe.running) stayAwakeStateProbe.running = true
  }

  function applyStayAwake(value, reason) {
    var enabled = !!value
    var changed = !root.stayAwakeStateLoaded || root.stayAwake !== enabled

    root.stayAwake = enabled
    root.stayAwakeStateLoaded = true

    if (!changed) return enabled ? "disabled" : "enabled"

    logEvent("stay-awake", (enabled ? "enabled" : "disabled") + (reason ? " " + reason : ""))
    if (enabled) root.endIdleCycle("stay-awake")
    Qt.callLater(root.handleIdleChanged)

    return enabled ? "disabled" : "enabled"
  }

  function setIdleEnabled(value) {
    if (idleToggleProcess.running) return root.idleEnabled ? "enabled" : "disabled"
    idleToggleProcess.command = ["bash", "-lc", value
      ? "strata-toggle-idle allow-idle"
      : "strata-toggle-idle stay-awake"]
    idleToggleProcess.running = true
    return value ? "enabled" : "disabled"
  }

  onLockEnabledChanged: if (!lockEnabled) endIdleCycle("idle-lock-disabled")

  IdleMonitor {
    id: idleMonitor
    enabled: root.lockEnabled
    timeout: Math.max(1, root.lockTimeoutSeconds)
    respectInhibitors: true
    onIsIdleChanged: root.handleIdleChanged()
  }

  Process {
    id: lockProcess
    onExited: function(exitCode, exitStatus) { root.logEvent("process-exit", "lock exitCode=" + exitCode + " status=" + exitStatus) }
  }

  Process {
    id: wakeProcess
    onExited: function(exitCode, exitStatus) { root.logEvent("process-exit", "wake exitCode=" + exitCode + " status=" + exitStatus) }
  }

  Process {
    id: stayAwakeStateProbe
    command: ["bash", "-c", "mkdir -p \"$HOME/.local/state/strata/indicators\"; if [[ -f $HOME/.local/state/strata/indicators/stay-awake ]]; then echo yes; else echo no; fi"]
    stdout: SplitParser {
      onRead: function(line) { root.applyStayAwake(String(line).trim() === "yes", "state-file") }
    }
    onExited: function() { stayAwakeStateDirWatcher.reload() }
  }

  Process {
    id: idleToggleProcess
    onExited: function() {
      root.refreshStayAwakeState()
    }
  }

  FileView {
    id: stayAwakeStateDirWatcher
    path: root.stayAwakeStateDir
    watchChanges: true
    printErrors: false
    onFileChanged: root.refreshStayAwakeState()
  }

  Component.onCompleted: {
    logEvent("service-ready")
    refreshStayAwakeState()
    idleToggleProcess.command = ["bash", "-lc", "strata-toggle-idle sync"]
    idleToggleProcess.running = true
  }

  ShellIpc {
    target: "idle"

    function status(): string { return root.statusJson() }
    function debug(): string { return root.statusJson() }
    function enable(): string { return root.setIdleEnabled(true) }
    function disable(): string { return root.setIdleEnabled(false) }
    function toggle(): string { return root.setIdleEnabled(!root.idleEnabled) }
  }
}

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower
import qs.Commons

Item {
  id: root

  // Injected by strata-shell (the first-party service loader).
  property var shell: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string stayAwakeStateDir: home + "/.local/state/strata/indicators"
  readonly property string stayAwakeStatePath: stayAwakeStateDir + "/stay-awake"
  readonly property string settingsPath: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/strata/idle-settings.json"
  property bool remoteDesktopActive: false
  onRemoteDesktopActiveChanged: if (remoteDesktopActive) root.displaysOff = false
  readonly property int defaultLockSeconds: 300
  readonly property var batteryService: shell && shell.services
    ? shell.firstPartyServiceFor("strata.power") : null
  readonly property string activePowerProfile: {
    var profile = batteryService ? String(batteryService.activePowerProfile || "") : ""
    return ["power-saver", "balanced", "performance"].indexOf(profile) >= 0 ? profile : "balanced"
  }
  readonly property string powerSource: UPower.onBattery ? "battery" : "ac"
  readonly property var sourceSettings: settingsState.sources && settingsState.sources[powerSource]
    ? settingsState.sources[powerSource] : ({ lid: settingsState.lid || "system", powerButton: "system" })
  readonly property int lockTimeoutSeconds: secondsFromConfig(settingsState.lock, defaultLockSeconds)
  readonly property bool lockEnabled: lockTimeoutSeconds > 0
  readonly property bool idleEnabled: stayAwakeStateLoaded && !stayAwake

  property bool stayAwake: false
  property bool stayAwakeRequested: false
  readonly property bool stayAwakeFailed: stayAwakeRequested && !stayAwake
  property bool stayAwakeStateLoaded: false
  property var settingsState: ({ display: 660, lock: 300, sleep: 1800, hibernate: 0, lid: "system" })
  property string settingsError: ""
  property bool settingsRefreshPending: false
  readonly property bool lidPresent: lidService.present
  readonly property bool hibernateAvailable: lidService.hibernateAvailable
  readonly property bool suspendThenHibernateAvailable: lidService.suspendThenHibernateAvailable
  property bool idleCycleRunning: false
  property int timerIdleTransitions: 0
  property string lastTimerIdleAt: ""
  property bool displaysOff: false
  property bool timerRearming: false
  readonly property bool timerCycleEnabled: stayAwakeStateLoaded && !stayAwake && !remoteDesktopActive
    && (settingsState.display > 0 || settingsState.sleep > 0)
  readonly property int firstTimerSeconds: Math.max(1, Math.min(
    settingsState.display > 0 ? settingsState.display : 604800,
    settingsState.sleep > 0 ? settingsState.sleep : 604800))
  property bool idledThisCycle: false
  property bool lockMonitorRearming: false
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
    if (!root.lockEnabled || root.remoteDesktopActive) return
    if (idleMonitor.isIdle) lockSystem("lock-timeout")
    else endIdleCycle("activity")
  }

  function statusJson() {
    return JSON.stringify({
      enabled: root.idleEnabled,
      stayAwake: root.stayAwake,
      remoteDesktopActive: root.remoteDesktopActive,
      stayAwakeRequested: root.stayAwakeRequested,
      stayAwakeFailed: root.stayAwakeFailed,
      settings: root.settingsState,
      activePowerProfile: root.activePowerProfile,
      powerSource: root.powerSource,
      lidAction: root.sourceSettings.lid,
      powerButtonAction: powerButtonService.action,
      powerButtonReady: powerButtonService.ready,
      settingsError: root.settingsError,
      lidPresent: root.lidPresent,
      hibernateAvailable: root.hibernateAvailable,
      suspendThenHibernateAvailable: root.suspendThenHibernateAvailable,
      timerCycleRunning: root.idleCycleRunning,
      timerEnabled: root.timerCycleEnabled,
      timerIdle: timerMonitor.isIdle,
      timerIdleTransitions: root.timerIdleTransitions,
      lastTimerIdleAt: root.lastTimerIdleAt,
      firstTimerSeconds: root.firstTimerSeconds,
      displaysOff: root.displaysOff,
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

  function applyStayAwake(status, reason) {
    var enabled = status.enabled === true
    var requested = status.requested === true
    var changed = !root.stayAwakeStateLoaded || root.stayAwake !== enabled || root.stayAwakeRequested !== requested

    root.stayAwake = enabled
    root.stayAwakeRequested = requested
    root.stayAwakeStateLoaded = true

    if (!changed) return enabled ? "disabled" : "enabled"

    logEvent("stay-awake", (enabled ? "enabled" : (requested ? "failed" : "disabled")) + (reason ? " " + reason : ""))
    if (enabled) root.endIdleCycle("stay-awake")
    Qt.callLater(root.handleIdleChanged)

    return enabled ? "disabled" : "enabled"
  }

  function setIdleEnabled(value) {
    if (idleToggleProcess.running) return root.idleEnabled ? "enabled" : "disabled"
    idleToggleProcess.command = ["strata-toggle-idle", value ? "allow-idle" : "stay-awake"]
    idleToggleProcess.running = true
    return value ? "enabled" : "disabled"
  }

  function parseSettings(text) {
    try {
      var data = JSON.parse(String(text))
      if (data && (data.profile !== root.activePowerProfile || data.powerSource !== root.powerSource)) {
        root.settingsRefreshPending = true
      } else if (data && typeof data === "object" && data.display >= 0 && data.sleep >= 0) {
        root.settingsState = data
        root.settingsError = ""
      }
    } catch (error) {
      root.settingsError = "Could not read idle settings"
    }
  }

  function refreshSettings() {
    if (settingsReadProcess.running) {
      root.settingsRefreshPending = true
      return
    }
    root.settingsRefreshPending = false
    settingsReadProcess.command = ["strata-idle-settings", "get", root.activePowerProfile, root.powerSource]
    settingsReadProcess.running = true
  }

  onActivePowerProfileChanged: refreshSettings()
  onPowerSourceChanged: refreshSettings()

  function rearmTimerCycle() {
    cancelTimerCycle()
    root.timerRearming = true
    Qt.callLater(function() { root.timerRearming = false })
  }

  function startTimerCycle() {
    if (!root.timerCycleEnabled || root.idleCycleRunning) return
    root.idleCycleRunning = true
    if (root.settingsState.display > 0) {
      if (root.settingsState.display <= root.firstTimerSeconds) root.turnDisplaysOff()
      else displayTimer.restart()
    }
    if (root.settingsState.sleep > 0) {
      if (root.settingsState.sleep <= root.firstTimerSeconds) root.requestSleep()
      else sleepTimer.restart()
    }
  }

  function cancelTimerCycle() {
    displayTimer.stop()
    sleepTimer.stop()
    root.idleCycleRunning = false
    if (root.displaysOff && !root.remoteDesktopActive) {
      root.displaysOff = false
      if (!displayOnProcess.running) displayOnProcess.running = true
    }
  }

  function turnDisplaysOff() {
    if (!root.timerCycleEnabled || displayOffProcess.running) return
    root.displaysOff = true
    displayOffProcess.running = true
  }

  function requestSleep() {
    if (!root.timerCycleEnabled || sleepProcess.running) return
    sleepProcess.command = root.settingsState.hibernate > 0
      ? ["strata-idle-settings", "sleep", "--hibernate-after"]
      : ["systemctl", "suspend"]
    sleepProcess.running = true
  }

  onSettingsStateChanged: rearmTimerCycle()
  onTimerCycleEnabledChanged: rearmTimerCycle()

  onLockEnabledChanged: if (!lockEnabled) endIdleCycle("idle-lock-disabled")
  onLockTimeoutSecondsChanged: {
    root.lockMonitorRearming = true
    Qt.callLater(function() { root.lockMonitorRearming = false })
  }

  IdleMonitor {
    id: idleMonitor
    enabled: root.lockEnabled && !root.lockMonitorRearming && !root.remoteDesktopActive
    timeout: Math.max(1, root.lockTimeoutSeconds)
    respectInhibitors: true
    onIsIdleChanged: root.handleIdleChanged()
  }

  IdleMonitor {
    id: timerMonitor
    enabled: root.timerCycleEnabled && !root.timerRearming
    timeout: root.firstTimerSeconds
    respectInhibitors: true
    onIsIdleChanged: {
      root.logEvent("sleep-timer", isIdle ? "idle" : "active")
      if (isIdle) {
        root.timerIdleTransitions += 1
        root.lastTimerIdleAt = root.nowIso()
        root.startTimerCycle()
      }
      else root.cancelTimerCycle()
    }
  }

  Timer {
    id: displayTimer
    interval: Math.max(1, root.settingsState.display - root.firstTimerSeconds) * 1000
    onTriggered: root.turnDisplaysOff()
  }

  Timer {
    id: sleepTimer
    interval: Math.max(1, root.settingsState.sleep - root.firstTimerSeconds) * 1000
    onTriggered: root.requestSleep()
  }

  LidService {
    id: lidService
    action: root.sourceSettings.lid || "system"
    hibernateAfterSleep: root.settingsState.hibernate > 0
    onErrorOccurred: function(message) { root.settingsError = message }
  }

  PowerButtonService {
    id: powerButtonService
    shell: root.shell
    action: root.sourceSettings.powerButton || "system"
    hibernateAvailable: root.hibernateAvailable
    hibernateAfterSleep: root.settingsState.hibernate > 0
    onErrorOccurred: function(message) { root.settingsError = message }
  }

  Process {
    id: settingsInitProcess
    command: ["strata-idle-settings", "init"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseSettings(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.settingsError = "Could not initialize idle settings"
      root.refreshSettings()
    }
  }

  Process {
    id: settingsReadProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseSettings(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.settingsError = "Could not load idle settings"
      if (root.settingsRefreshPending) root.refreshSettings()
    }
  }

  FileView {
    id: remoteDesktopState
    path: (Quickshell.env("XDG_RUNTIME_DIR") || ("/run/user/" + Quickshell.env("UID"))) + "/strata-remote-desktop/active"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.remoteDesktopActive = !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
      && String(text()).trim() === Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    onLoadFailed: root.remoteDesktopActive = false
  }

  // The optional helper's directory may not exist when this service starts.
  // Reload also covers creation after a failed initial file watch.
  Timer {
    interval: 1000
    repeat: true
    running: true
    onTriggered: remoteDesktopState.reload()
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    printErrors: false
    onFileChanged: root.refreshSettings()
  }

  Process {
    id: displayOffProcess
    command: ["hyprctl", "dispatch", "hl.dsp.dpms({ action = \"off\" })"]
    onExited: function(exitCode) {
      root.logEvent("displays-off", "exitCode=" + exitCode)
      if (exitCode !== 0) {
        root.displaysOff = false
        root.settingsError = "Could not turn displays off"
      }
    }
  }

  Process {
    id: displayOnProcess
    command: ["hyprctl", "dispatch", "hl.dsp.dpms({ action = \"enable\" })"]
    onExited: lidService.reapplyAfterGlobalDisplayOn()
  }

  Process {
    id: sleepProcess
    onExited: function(exitCode) {
      root.logEvent("sleep", "exitCode=" + exitCode)
      root.cancelTimerCycle()
      if (exitCode !== 0) root.settingsError = "Sleep was blocked or unavailable"
    }
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
    command: ["strata-toggle-idle", "--status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.applyStayAwake(JSON.parse(String(text)), "service-status") }
        catch (error) { root.logEvent("stay-awake-status-error", String(error)) }
      }
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

  Timer {
    interval: 5000
    repeat: true
    running: true
    onTriggered: root.refreshStayAwakeState()
  }

  Component.onCompleted: {
    logEvent("service-ready")
    settingsInitProcess.running = true
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
    function settings(): string { return root.statusJson() }
    function powerButton(): string { return powerButtonService.press() }
  }
}

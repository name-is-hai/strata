import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "NightlightModel.js" as Model

Item {
  id: root

  property var shell: null
  readonly property string settingsPath: Quickshell.env("HOME") + "/.config/strata/nightlight.json"
  property bool settingsLoaded: false
  property string mode: "manual"
  property int manualTemperature: 4000
  property int dayTemperature: 6500
  property int nightTemperature: 3400
  property int transitionMinutes: 30
  property real latitude: 0
  property real longitude: 0
  property bool locationConfigured: false
  property var pauseUntil: null
  property int temperature: 6500
  property int appliedTemperature: -1
  property int sunriseMinutes: -1
  property int sunsetMinutes: -1
  property string lastError: ""
  property bool savePending: false
  property bool applyPending: false
  property int pendingTemperature: 6500

  readonly property bool hasLocation: locationConfigured && Model.hasCoordinates(latitude, longitude)
  readonly property bool enabled: temperature < Model.IDENTITY_TEMPERATURE
  readonly property string statusText: mode === "auto"
    ? (pauseUntil && Date.now() < pauseUntil ? "Paused" : "Automatic")
    : "Manual"
  readonly property string sunriseText: Model.formatMinutes(sunriseMinutes >= 0 ? sunriseMinutes : null)
  readonly property string sunsetText: Model.formatMinutes(sunsetMinutes >= 0 ? sunsetMinutes : null)

  function persistableState() {
    return {
      version: 1,
      mode: mode,
      manualTemperature: manualTemperature,
      dayTemperature: dayTemperature,
      nightTemperature: nightTemperature,
      transitionMinutes: transitionMinutes,
      latitude: latitude,
      longitude: longitude,
      locationConfigured: locationConfigured,
      pauseUntil: pauseUntil
    }
  }

  function saveSettings() {
    savePending = false
    settingsFile.setText(JSON.stringify(persistableState(), null, 2) + "\n")
  }

  function scheduleSave() {
    if (!settingsLoaded) return
    savePending = true
    saveTimer.restart()
  }

  function loadSettings(raw) {
    var data = {}
    try { data = JSON.parse(String(raw || "{}")) || {} } catch (e) { data = {} }
    mode = data.mode === "auto" ? "auto" : "manual"
    manualTemperature = Model.clampTemperature(data.manualTemperature, 4000)
    dayTemperature = Model.clampTemperature(data.dayTemperature, 6500)
    nightTemperature = Model.clampTemperature(data.nightTemperature, 3400)
    transitionMinutes = Math.max(0, Math.min(180, Math.round(Number(data.transitionMinutes) || 30)))
    latitude = Number(data.latitude) || 0
    longitude = Number(data.longitude) || 0
    locationConfigured = data.locationConfigured === true
    pauseUntil = Number(data.pauseUntil) > Date.now() ? Number(data.pauseUntil) : null
    settingsLoaded = true
    tick()
  }

  function applyTemperature(value) {
    var next = Model.clampTemperature(value, temperature)
    temperature = next
    if (Math.abs(next - appliedTemperature) < 50) return
    if (applyProcess.running) {
      pendingTemperature = next
      applyPending = true
      return
    }
    runApply(next)
  }

  function runApply(value) {
    pendingTemperature = value
    applyProcess.command = ["strata-toggle-nightlight", "--temperature", String(value)]
    applyProcess.running = true
  }

  function setTemperature(value) {
    manualTemperature = Model.clampTemperature(value, manualTemperature)
    mode = "manual"
    pauseUntil = null
    scheduleSave()
    applyTemperature(manualTemperature)
  }

  function setNightlight(value) {
    setTemperature(value ? Math.min(manualTemperature, 4000) : Model.MAX_TEMPERATURE)
  }

  function toggle() {
    setNightlight(!enabled)
  }

  function setMode(value) {
    mode = value === "auto" ? "auto" : "manual"
    if (mode === "manual") pauseUntil = null
    scheduleSave()
    tick()
  }

  function setLocation(lat, lon) {
    if (String(lat).trim() === "" || String(lon).trim() === "") {
      lastError = "Enter latitude and longitude to use local sunrise and sunset."
      return false
    }
    var nextLat = Number(lat)
    var nextLon = Number(lon)
    if (!isFinite(nextLat) || Math.abs(nextLat) > 90 || !isFinite(nextLon) || Math.abs(nextLon) > 180) {
      lastError = "Enter valid latitude and longitude."
      return false
    }
    latitude = nextLat
    longitude = nextLon
    locationConfigured = true
    lastError = ""
    scheduleSave()
    tick()
    return true
  }

  function setDayTemperature(value) {
    dayTemperature = Model.clampTemperature(value, dayTemperature)
    scheduleSave()
    tick()
  }

  function setNightTemperature(value) {
    nightTemperature = Model.clampTemperature(value, nightTemperature)
    scheduleSave()
    tick()
  }

  function setTransition(value) {
    transitionMinutes = Math.max(0, Math.min(180, Math.round(Number(value) || 0)))
    scheduleSave()
    tick()
  }

  function preset(name) {
    var values = { day: 6500, evening: 4000, night: 3400, candle: 1900 }
    if (values[name] === undefined) return
    setTemperature(values[name])
  }

  function pauseFor(seconds) {
    if (mode !== "auto") mode = "auto"
    pauseUntil = Date.now() + Math.max(1, Number(seconds) || 3600) * 1000
    scheduleSave()
    tick()
  }

  function pauseUntilSunrise() {
    recomputeSun()
    var now = new Date()
    var target = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 6, 0, 0)
    if (hasLocation && sunriseMinutes >= 0) target.setHours(Math.floor(sunriseMinutes / 60), sunriseMinutes % 60, 0, 0)
    if (target.getTime() <= now.getTime()) target.setDate(target.getDate() + 1)
    pauseUntil = target.getTime()
    mode = "auto"
    scheduleSave()
    tick()
  }

  function clearPause() {
    pauseUntil = null
    scheduleSave()
    tick()
  }

  function recomputeSun() {
    if (!hasLocation) {
      sunriseMinutes = -1
      sunsetMinutes = -1
      return
    }
    var times = Model.sunTimes(latitude, longitude, new Date())
    sunriseMinutes = times.sunrise === null ? -1 : times.sunrise
    sunsetMinutes = times.sunset === null ? -1 : times.sunset
  }

  function tick() {
    recomputeSun()
    if (!settingsLoaded) return
    if (pauseUntil && Date.now() >= pauseUntil) {
      pauseUntil = null
      scheduleSave()
    }
    if (mode !== "auto") return
    if (pauseUntil && Date.now() < pauseUntil) {
      applyTemperature(dayTemperature)
      return
    }
    var now = new Date()
    var sunrise = hasLocation ? sunriseMinutes : 6 * 60
    var sunset = hasLocation ? sunsetMinutes : 18 * 60
    applyTemperature(Model.scheduledTemperature({
      dayTemperature: dayTemperature,
      nightTemperature: nightTemperature,
      sunriseMinutes: sunrise,
      sunsetMinutes: sunset,
      nowMinutes: now.getHours() * 60 + now.getMinutes(),
      transitionMinutes: transitionMinutes
    }))
  }

  function refresh() {
    if (!statusProbe.running) statusProbe.running = true
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    atomicWrites: true
    printErrors: false
    onLoaded: if (!root.settingsLoaded) root.loadSettings(text())
    onLoadFailed: if (!root.settingsLoaded) root.loadSettings("{}")
  }

  Timer {
    id: saveTimer
    interval: 250
    repeat: false
    onTriggered: root.saveSettings()
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: {
      root.tick()
      root.refresh()
    }
  }

  Process {
    id: statusProbe
    command: ["strata-toggle-nightlight", "--status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(String(text || "{}"))
          if (data.temperature !== null && data.temperature !== undefined) {
            root.temperature = Model.clampTemperature(data.temperature, root.temperature)
            root.appliedTemperature = root.temperature
          }
          if (root.settingsLoaded && root.mode === "manual") root.manualTemperature = root.temperature
        } catch (e) {}
      }
    }
  }

  Process {
    id: applyProcess
    onExited: function(exitCode) {
      if (exitCode === 0) root.appliedTemperature = root.pendingTemperature
      else root.lastError = "Could not apply color temperature."
      if (root.applyPending) {
        root.applyPending = false
        root.runApply(root.pendingTemperature)
      }
    }
  }

  Component.onCompleted: {
    settingsFile.reload()
    refresh()
  }

  ShellIpc {
    target: "nightlight"
    function status(): string {
      return JSON.stringify({
        enabled: root.enabled, temperature: root.temperature, mode: root.mode,
        sunrise: root.sunriseText, sunset: root.sunsetText, hasLocation: root.hasLocation,
        pauseUntil: root.pauseUntil, status: root.statusText, error: root.lastError
      })
    }
    function refresh(): void { root.refresh() }
    function enable(): string { root.setNightlight(true); return "enabled" }
    function disable(): string { root.setNightlight(false); return "disabled" }
    function toggle(): string { root.toggle(); return root.enabled ? "enabled" : "disabled" }
    function setTemperature(value: string): string { root.setTemperature(Number(value)); return "ok" }
    function setMode(value: string): string { root.setMode(value); return root.mode }
    function pause(value: string): string {
      if (value === "sunrise") root.pauseUntilSunrise()
      else if (value === "clear" || value === "0") root.clearPause()
      else root.pauseFor(Number(value))
      return "ok"
    }
    function location(lat: string, lon: string): string { return root.setLocation(lat, lon) ? "ok" : root.lastError }
    function preset(value: string): string { root.preset(value); return "ok" }
  }
}

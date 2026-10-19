.pragma library

// The rules behind the system-sounds service, kept free of QML so they can be
// read on their own and run under node (tests/sounds.test.js).

function localPath(url) {
  return decodeURIComponent(String(url || "").replace(/^file:\/\//, "")).replace(/\/+$/, "")
}

function parseObject(text) {
  try {
    var value = JSON.parse(String(text || ""))
    return value && typeof value === "object" && !Array.isArray(value) ? value : {}
  } catch (e) {
    return {}
  }
}

// events.json -> { id: event }
function catalogueFrom(text) {
  var list = parseObject(text).events
  var map = {}
  if (Array.isArray(list)) {
    for (var i = 0; i < list.length; i++) {
      if (list[i] && list[i].id) map[list[i].id] = list[i]
    }
  }
  return map
}

function masterOn(config) {
  return !config || config.enabled !== false
}

function eventOn(config, catalogue, id) {
  var events = config && config.events
  if (events && typeof events === "object" && Object.prototype.hasOwnProperty.call(events, id))
    return events[id] === true
  var entry = catalogue ? catalogue[id] : null
  return entry ? entry.default !== false : true
}

// The shortest gap between two plays of one event. Holding a key, dragging a
// slider or plugging in a hub full of devices produces a burst of events, and
// a burst should sound once, the way Windows does it.
var GAPS = {
  "bell": 90,
  "audio-volume-change": 140,
  "device-added": 1000,
  "device-removed": 1000,
  "bluetooth-connect": 1000,
  "bluetooth-disconnect": 1000,
  "notification": 300,
  "power-plug": 2000,
  "power-unplug": 2000,
  "theme-change": 2000,
  "trash-empty": 1500
}

function minimumGap(id) {
  return GAPS[id] !== undefined ? GAPS[id] : 400
}

// Events that hardware and daemons replay while the session is still settling,
// after login or a wake from sleep, rather than because anyone did anything.
var SETTLING = ["device-added", "device-removed", "bluetooth-connect", "bluetooth-disconnect",
                "power-plug", "power-unplug", "audio-volume-change", "battery-low", "battery-critical"]

function settles(id) {
  return SETTLING.indexOf(id) >= 0
}

// `udevadm monitor --udev --subsystem-match=usb/usb_device` prints a header
// line per event, e.g.
//   UDEV  [1234.567890] add      /devices/pci0000:00/.../1-3 (usb)
function udevAction(line) {
  var match = /^UDEV\s+\[[^\]]*\]\s+(add|remove)\s+\S+\s+\(usb\)/.exec(String(line || ""))
  return match ? match[1] : ""
}

// `gdbus monitor --system --dest org.freedesktop.login1` prints signals as
//   /org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (true,)
function logindSignal(line) {
  var match = /\.(PrepareForSleep|PrepareForShutdown)\s*\((true|false)\s*,?\s*\)/.exec(String(line || ""))
  return match ? { name: match[1], active: match[2] === "true" } : null
}

// `gdbus monitor --system --dest org.bluez` prints property changes as
//   /org/bluez/hci0/dev_AA_BB: org.freedesktop.DBus.Properties.PropertiesChanged
//     ('org.bluez.Device1', {'Connected': <true>, ...}, @as [])
// Returns true or false for a Connected change, otherwise null.
function bluezConnected(line) {
  var match = /PropertiesChanged \('org\.bluez\.Device1', (?:@a\{sv\} )?\{.*'Connected': <(true|false)>/.exec(String(line || ""))
  return match ? match[1] === "true" : null
}

// The sound a Hyprland event maps to in sounds.json's "hyprland" object. A key
// can be a bare event name ("monitoradded") or name:data for an exact payload
// ("openlayer:strata-menu").
function hyprlandSound(config, name, data) {
  var map = config && config.hyprland
  if (!map || typeof map !== "object") return ""
  var exact = map[name + ":" + data]
  var sound = typeof exact === "string" ? exact : map[name]
  return typeof sound === "string" && sound !== "none" ? sound : ""
}

// ---------------------------------------------------------- notifications

// Checked after the user's own rules from sounds.json. A rule matches on app
// name and/or summary (case-insensitive regular expressions) and names the
// sound to play, or "none".
var NOTIFICATION_RULES = [
  { app: "^strata-action$", summary: "^Reminder$", sound: "reminder" },
  { app: "^strata-action$", summary: "^Screenshot (saved|copied)", sound: "screen-capture" },
  { app: "^strata-action$", summary: "^Process crashed:", sound: "error" },
  // The low-battery alarm already sounded from UPower; one alarm is enough.
  { app: "^strata-action$", summary: "^Time to recharge", sound: "none" },
  // Track-change toasts, not messages.
  { app: "^spotify$", sound: "none" },
  // Discord clients ring their own message sound; a second one on top is noise.
  { app: "^(discord|discord canary|discord ptb|vesktop|equibop|legcord|armcord|webcord)$", sound: "none" }
]

function matches(pattern, value) {
  if (pattern === undefined || pattern === null || pattern === "") return true
  try {
    return new RegExp(String(pattern), "i").test(String(value || ""))
  } catch (e) {
    return String(pattern).toLowerCase() === String(value || "").toLowerCase()
  }
}

function hint(hints, name) {
  var entry = hints ? hints[name] : undefined
  // busctl --json wraps every variant as { type, data }.
  if (entry && typeof entry === "object" && Object.prototype.hasOwnProperty.call(entry, "data")) return entry.data
  return entry
}

// One line of `busctl --user monitor --json=short` for a Notify call ->
// { app, summary, body, replacesId, urgency, hints }, or null.
function notificationFrom(line) {
  var message
  try {
    message = JSON.parse(String(line || ""))
  } catch (e) {
    return null
  }
  if (!message || message.type !== "method_call" || message.member !== "Notify") return null
  var data = message.payload && message.payload.data
  if (!Array.isArray(data) || data.length < 7) return null
  var hints = data[6] && typeof data[6] === "object" ? data[6] : {}
  var urgency = Number(hint(hints, "urgency"))
  return {
    app: String(data[0] || ""),
    replacesId: Number(data[1]) || 0,
    summary: String(data[3] || ""),
    body: String(data[4] || ""),
    urgency: isFinite(urgency) ? urgency : 1,
    hints: hints
  }
}

// Strata lets these notifications bypass Do Not Disturb,
// so their sound comes through too.
function bypassesDnd(note) {
  return note.app === "strata-action" || (note.app === "notify-send" && note.urgency === 2)
}

function ruleFor(config, note) {
  var rules = (config && Array.isArray(config.notifications) ? config.notifications : []).concat(NOTIFICATION_RULES)
  for (var i = 0; i < rules.length; i++) {
    var rule = rules[i]
    if (!rule || typeof rule !== "object" || typeof rule.sound !== "string") continue
    if (rule.urgency !== undefined && ["low", "normal", "critical"].indexOf(String(rule.urgency)) !== note.urgency) continue
    if (matches(rule.app, note.app) && matches(rule.summary, note.summary)) return rule
  }
  return null
}

// What a notification should sound like:
//   { sound, fallback, gate } to play an event, gate being the switch that
//   must be on; { file, gate } to play a file the sender named; or null.
function notificationSound(config, catalogue, note, dnd) {
  if (!note || note.replacesId > 0) return null              // an update to a toast already shown
  if (hint(note.hints, "suppress-sound") === true) return null
  if (dnd && !bypassesDnd(note)) return null

  var rule = ruleFor(config, note)
  if (rule) {
    if (rule.sound === "none" || rule.sound === "") return null
    var builtin = !!(catalogue && catalogue[rule.sound])
    return { sound: rule.sound, fallback: ["notification"], gate: builtin ? rule.sound : "notification" }
  }

  var file = hint(note.hints, "sound-file")
  if (typeof file === "string" && file.indexOf("/") === 0) return { file: file, gate: "notification" }

  var name = hint(note.hints, "sound-name")
  if (typeof name === "string" && /^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(name))
    return { sound: name, fallback: ["notification"], gate: "notification" }

  return { sound: "notification", fallback: [], gate: "notification" }
}

if (typeof module !== "undefined") {
  module.exports = {
    localPath: localPath,
    parseObject: parseObject,
    catalogueFrom: catalogueFrom,
    masterOn: masterOn,
    eventOn: eventOn,
    minimumGap: minimumGap,
    settles: settles,
    udevAction: udevAction,
    logindSignal: logindSignal,
    bluezConnected: bluezConnected,
    hyprlandSound: hyprlandSound,
    notificationFrom: notificationFrom,
    notificationSound: notificationSound
  }
}

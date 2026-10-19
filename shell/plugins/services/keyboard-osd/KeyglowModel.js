function normalizedParts(parts) {
  if (!parts || typeof parts === "string" ||
      typeof parts.length !== "number" || parts.length < 2) return null

  var description = []
  for (var index = 1; index < parts.length; index += 1) {
    description.push(String(parts[index] || ""))
  }
  return [parts[0], description.join(",")]
}
function eventParts(event) {
  var parts
  try {
    if (event && event.parse) parts = event.parse(2)
  } catch (error) {
  }

  var parsed = normalizedParts(parts)
  if (parsed) return parsed

  var raw = String(event && event.data ? event.data : "")
  var separator = raw.indexOf(",")
  if (separator === -1) return [raw, ""]
  return [raw.substring(0, separator), raw.substring(separator + 1)]
}

function activeWindow(event) {
  if (!event || String(event.name || "") !== "activewindowv2") return null

  var address = String(event.data || "").trim()
  if (!address && event.parse) {
    try {
      var parts = event.parse(1)
      address = String(parts && parts[0] || "").trim()
    } catch (error) {
    }
  }
  return address || null
}

// Fcitx virtual keyboards announce layout synchronization when window focus
// changes. Physical keyboards announce the user's actual layout switches.
var NON_PHYSICAL_KEYBOARDS = /^(?:hl-virtual-keyboard|power-button|sleep-button|lid-switch|video-bus)|(?:^|-)(?:hotkeys|extra-buttons)$/i

function isPhysicalKeyboard(name) {
  var keyboardName = String(name || "").trim()
  return keyboardName !== "" && !NON_PHYSICAL_KEYBOARDS.test(keyboardName)
}

function physicalLayout(event) {
  if (!event || String(event.name || "") !== "activelayout") return null

  var parts = eventParts(event)
  var keyboardName = String(parts[0] || "").trim()
  var description = String(parts[1] || "").trim()
  return isPhysicalKeyboard(keyboardName) && description ? description : null
}

function yamlValue(value) {
  var text = String(value || "").trim()
  if (text.length >= 2 && text.charAt(0) === "'" && text.charAt(text.length - 1) === "'")
    return text.substring(1, text.length - 1).replace(/''/g, "'")
  return text
}

// xkbcli pairs each description reported by Hyprland with both a language
// brief (English -> en) and an XKB layout id (English (US) -> us).
function layoutLabels(text) {
  var labels = {}
  var layout = ""
  var brief = ""

  String(text || "").split("\n").forEach(function (line) {
    if (/^- /.test(line)) {
      layout = ""
      brief = ""
    }

    var layoutField = line.match(/^- layout: (.*)$/)
    if (layoutField) {
      layout = yamlValue(layoutField[1])
      return
    }

    var field = line.match(/^  (brief|description): (.*)$/)
    if (!field || !layout) return
    if (field[1] === "brief") {
      brief = yamlValue(field[2])
      return
    }

    var description = yamlValue(field[2])
    if (!description) return
    var existing = labels[description]
    var language = brief ? brief.split("-")[0] : ""
    labels[description] = {
      language: existing && existing.language !== language ? "" : language,
      layout: existing && existing.layout !== layout ? "" : layout
    }
  })

  return labels
}

function displayLabel(description, style, labels) {
  var full = String(description || "").trim()
  if (!full) return ""

  var selectedStyle = ["language", "layout"].indexOf(String(style || "").toLowerCase()) !== -1
    ? String(style).toLowerCase() : "full"
  if (selectedStyle === "full") return full

  var entry = (labels || {})[full]
  var code = entry && typeof entry[selectedStyle] === "string" ? entry[selectedStyle] : ""
  return code ? code.substring(0, 3).toUpperCase() : full
}

function inputMethodLabel(method, displayName) {
  var value = String(method || "").trim()
  var known = {
    "keyboard-us": "English (US)", "unikey": "Vietnamese (Unikey)",
    "keyboard-vn": "Vietnamese"
  }
  return known[value] || String(displayName || "").replace(/^Keyboard - /, "").trim()
    || value.replace(/^keyboard-/, "")
}

function pluginSettings(config, pluginId) {
  var plugins = config && Array.isArray(config.plugins) ? config.plugins : []
  for (var index = 0; index < plugins.length; index += 1) {
    if (plugins[index] && String(plugins[index].id || "") === String(pluginId || ""))
      return plugins[index]
  }
  return {}
}

function durationSetting(settings) {
  var raw = settings && settings.durationMs
  var duration = raw === undefined || raw === null || raw === "" ? NaN : Number(raw)
  if (!isFinite(duration)) duration = 800
  return Math.max(200, Math.min(5000, Math.round(duration)))
}

function osdPayload(description, settings, labels) {
  var style = settings && settings.labelStyle
  var message = displayLabel(description, style, labels)
  if (!message) return null

  // An omitted/empty icon makes native Omarchy OSD fall back to a speaker.
  // A zero-width literal glyph uses its custom-icon path without visible ink.
  var payload = {
    message: message,
    duration: durationSetting(settings),
    icon: settings && settings.showIcon === false ? "\u200b" : "keyboard"
  }
  return payload
}

if (typeof module !== "undefined") {
  module.exports = {
    activeWindow: activeWindow,
    inputMethodLabel: inputMethodLabel,
    displayLabel: displayLabel,
    isPhysicalKeyboard: isPhysicalKeyboard,
    layoutLabels: layoutLabels,
    osdPayload: osdPayload,
    pluginSettings: pluginSettings,
    physicalLayout: physicalLayout
  }
}

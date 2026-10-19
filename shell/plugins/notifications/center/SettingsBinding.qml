import QtQuick
import Quickshell
import qs.Commons
Item {
  id: root
  property var owner: null
  property var service: null
  function setting(key, fallback) { return owner ? owner.setting(key, fallback) : fallback }
  readonly property string configuredDisplayMode: {
    var mode = String(setting("displayMode", "active"))
    return mode === "specific" || mode === "all" ? mode : "active"
  }
  readonly property string configuredDisplayName: String(setting("displayName", "") || "")
  readonly property bool configuredOfferSnoozeWhenSharing: setting("offerSnoozeWhenSharing", true) !== false
  readonly property bool configuredShowCountdown: setting("showCountdown", false) === true
  readonly property bool configuredPlaySound: setting("playSound", true) !== false
  readonly property int configuredPopupDuration: {
    var duration = Number(setting("popupDuration", 8))
    return [5, 8, 12].indexOf(duration) >= 0 ? duration : 8
  }
  readonly property string configuredPopupPosition: {
    var position = String(setting("popupPosition", "top-right"))
    return ["top-left", "top-center", "top-right", "bottom-left", "bottom-center", "bottom-right"].indexOf(position) >= 0
      ? position : "top-right"
  }
  readonly property var popupPositionOptions: [
    { value: "top-left", label: "Top left" },
    { value: "top-center", label: "Top center" },
    { value: "top-right", label: "Top right" },
    { value: "bottom-left", label: "Bottom left" },
    { value: "bottom-center", label: "Bottom center" },
    { value: "bottom-right", label: "Bottom right" }
  ]
  readonly property var popupDurationOptions: [
    { value: "5", label: "5 seconds" },
    { value: "8", label: "8 seconds" },
    { value: "12", label: "12 seconds" }
  ]
  readonly property var historyRetentionOptions: [
    { value: "0", label: "Do not keep history" },
    { value: "1", label: "1 hour" },
    { value: "24", label: "1 day" },
    { value: "168", label: "7 days" }
  ]
  readonly property string configuredFullscreenOverlay: {
    var mode = String(setting("fullscreenOverlay", "off"))
    return ["all", "steam", "all-away", "steam-away"].indexOf(mode) >= 0 ? mode : "off"
  }
  readonly property var fullscreenOverlayOptions: [
    { value: "off", label: "Nothing" },
    { value: "all", label: "Fullscreen windows" },
    { value: "steam", label: "Fullscreen Steam games" },
    { value: "all-away", label: "Fullscreen windows, never over them" },
    { value: "steam-away", label: "Fullscreen Steam games, never over them" }
  ]
  readonly property string fullscreenOverlayExplanation: {
    switch (configuredFullscreenOverlay) {
    case "all": return "Get out of the way of fullscreen windows, so they go straight to the display. A new notification still appears over them, then it steps aside again."
    case "steam": return "Get out of the way of fullscreen Steam games, so they go straight to the display. A new notification still appears over them, then it steps aside again."
    case "all-away": return "Never appear over a fullscreen window. New notifications go to another display instead, or wait in Recent if there is no other display."
    case "steam-away": return "Never appear over a fullscreen Steam game. New notifications go to another display instead, or wait in Recent if there is no other display."
    default: return "Stay over fullscreen windows. Hyprland then has to redraw every frame of a fullscreen game."
    }
  }
  readonly property bool configuredFetchRemoteIcons: setting("fetchRemoteIcons", true) !== false
  readonly property bool configuredRequireSandbox: setting("requireSandbox", false) === true
  readonly property int configuredEdgeSpacing: {
    var spacing = Number(setting("edgeSpacing", 12))
    return isFinite(spacing) ? Math.max(0, Math.min(64, Math.round(spacing))) : 12
  }
  readonly property var availableScreens: Quickshell.screens || []
  readonly property bool configuredDisplayPresent: {
    if (configuredDisplayName === "") return false
    var screens = availableScreens
    for (var i = 0; i < screens.length; i++)
      if (screens[i] && String(screens[i].name || "") === configuredDisplayName) return true
    return false
  }
  readonly property string displayChoice: configuredDisplayMode === "specific"
    ? "output:" + configuredDisplayName : configuredDisplayMode
  readonly property var displayOptions: {
    var options = [
      { value: "active", label: "Active display" },
      { value: "all", label: "All displays" }
    ]
    for (var i = 0; i < availableScreens.length; i++) {
      var name = String(availableScreens[i].name || "")
      if (name) options.push({ value: "output:" + name, label: name })
    }
    if (configuredDisplayMode === "specific" && !configuredDisplayPresent)
      options.push({ value: displayChoice, label: configuredDisplayName
        ? configuredDisplayName + " (disconnected)" : "Select a display" })
    return options
  }
  readonly property string displayExplanation: configuredDisplayMode === "all"
    ? "Show notifications on all connected displays."
    : configuredDisplayMode === "specific" && configuredDisplayPresent
      ? "Show notifications on " + configuredDisplayName + "."
      : configuredDisplayMode === "specific"
        ? "Selected display disconnected. Using the active display."
        : "Use the focused display for new notification groups."
  readonly property string sharingDetectionStatus: service && service.sharingDetectionStatus
    ? String(service.sharingDetectionStatus) : "Sharing detection unavailable: service not ready"

  function applySettings() {
    if (!service) return
    service.requireSandbox = configuredRequireSandbox
    var stacking = String(setting("stacking", "source"))
    if ((stacking === "all" || stacking === "source") && service.stacking !== stacking)
      service.commit(function() { service.stacking = stacking })
    var fontScale = Number(setting("fontScale", 100))
    service.fontScale = isFinite(fontScale) ? Math.max(75, Math.min(200, fontScale)) / 100 : 1
    service.edgeSpacing = configuredEdgeSpacing
    service.popupPosition = configuredPopupPosition
    service.showCountdown = configuredShowCountdown
    service.playSound = configuredPlaySound
    service.normalDuration = configuredPopupDuration * 1000
    service.fullscreenOverlay = configuredFullscreenOverlay
    var align = String(setting("actionsAlign", "right"))
    if (align === "left" || align === "right") service.actionsAlign = align
    service.setFetchRemoteIcons(configuredFetchRemoteIcons)
    service.allowDefaultActionOnCardClick = setting("allowDefaultActionOnCardClick", false) === true
    var lifetime = Number(setting("clipboardTimeout", 60))
    service.clipboardTimeout = [30, 60, 90].indexOf(lifetime) >= 0 ? lifetime : 60
    var hours = Number(setting("historyHours", 24))
    service.setHistoryHours([0, 1, 24, 168].indexOf(hours) >= 0 ? hours : 24, Number(setting("maxItems", 100)))
    service.hideSettingsAction = setting("hideSettingsAction", true) !== false
    // Only when it has actually been configured. An explicit setting is an
    // instruction; the default is not one - and the panel's own key toggle is
    // persisted, so applying the default on every reload would quietly undo it.
    var codes = setting("codesBypassQuiet", null)
    if (codes !== null) service.setCodesBypassQuiet(codes !== false)
    service.smartRaise = setting("smartRaise", true) !== false
    service.wakeHour = Number(setting("wakeHour", 8)) || 8
    service.sourceLimit = Number(setting("sourceLimit", 8)) || 8
    service.heldPerSource = Number(setting("heldPerSource", 10)) || 10
    // Empty means "none chosen", not "no snoozing" - fall back rather than
    // leaving a menu with nothing in it.
    var chosen = setting("snoozeDurations", null)
    if (chosen && chosen.length > 0) service.snoozeChoices = chosen

    // The bar widget is the only object with the plugin's shell.json entry.
    // Keep the output name before the mode so selecting a present monitor does
    // not pass through a transient specific-without-a-name state.
    service.displayName = configuredDisplayName
    service.displayMode = configuredDisplayMode
    service.offerSnoozeWhenSharing = configuredOfferSnoozeWhenSharing
    service.helperSettingsReady = true
  }

  Connections {
    target: root.owner
    function onSettingsChanged() { Qt.callLater(root.applySettings) }
  }
  onServiceChanged: Qt.callLater(applySettings)
  Component.onCompleted: Qt.callLater(applySettings)
}

import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "../wireless-display" as Wireless

BarWidget {
  id: root
  moduleName: "strata.cast"
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property bool castingEnabled: setting("discoveryEnabled", false) === true
  property string selectedTab: setting("lastTab", "screen") === "media" ? "media" : "screen"
  property bool pendingOpen: false
  property bool ready: false
  readonly property var currentPanel: selectedTab === "screen" ? screenLoader.item : panelLoader.item
  readonly property bool casting: (screenLoader.item && screenLoader.item.hasConnected)
    || (panelLoader.item && panelLoader.item.casting)
  readonly property string receiverName: screenLoader.item && screenLoader.item.hasConnected
    ? screenLoader.item.state.connected.map(function(p) { return p.name || p.address }).join(", ")
    : panelLoader.item ? panelLoader.item.connectedReceiver : ""
  readonly property bool opened: !!currentPanel && currentPanel.opened
  readonly property bool popoutSwitchClosing: !!currentPanel && currentPanel.popoutSwitchClosing
  visible: castingEnabled
  implicitWidth: castingEnabled ? button.implicitWidth : 0
  implicitHeight: button.implicitHeight

  function saveSettings(changes) {
    var next = Object.assign({}, settings || {}, changes)
    if (bar && bar.shell) bar.shell.updateEntryInline(moduleName, next)
  }
  function selectTab(tab) {
    if (tab !== "screen" && tab !== "media" || selectedTab === tab) return
    var wasOpen = opened
    close()
    selectedTab = tab
    saveSettings({ lastTab: tab })
    if (wasOpen) Qt.callLater(root.open)
  }
  function open() {
    if (!castingEnabled) { pendingOpen = true; saveSettings({ discoveryEnabled: true }); return }
    if (currentPanel) { pendingOpen = false; currentPanel.open() }
    else pendingOpen = true
  }
  function close() {
    pendingOpen = false
    if (screenLoader.item) screenLoader.item.close()
    if (panelLoader.item) panelLoader.item.close()
  }
  function toggle() { opened ? close() : open() }
  function closeForPopoutSwitch() { if (currentPanel) currentPanel.closeForPopoutSwitch() }
  function injectPanels() {
    for (var item of [panelLoader.item, screenLoader.item]) {
      if (!item) continue
      item.bar = root.bar
      item.anchorItem = button
      item.hostWidget = root
    }
    if (pendingOpen) Qt.callLater(root.open)
  }
  onBarChanged: injectPanels()
  onSettingsChanged: {
    var tab = setting("lastTab", "screen") === "media" ? "media" : "screen"
    if (selectedTab !== tab) { close(); selectedTab = tab }
  }
  onCastingEnabledChanged: {
    if (!ready) return
    if (!castingEnabled) close()
    Quickshell.execDetached(["strata-casting-control", castingEnabled ? "start" : "stop"])
  }
  Component.onCompleted: { ready = true; if (castingEnabled) Quickshell.execDetached(["strata-casting-control", "start"]) }

  Timer {
    interval: 30000
    repeat: true
    running: root.castingEnabled && !root.casting
    onTriggered: Quickshell.execDetached(["strata-casting-control", "start"])
  }
  Loader {
    id: screenLoader
    active: root.castingEnabled
    visible: false
    sourceComponent: Component { Wireless.Panel { manageIpc: false } }
    onLoaded: root.injectPanels()
  }
  Loader {
    id: panelLoader
    active: root.castingEnabled
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: root.injectPanels()
  }

  // Use BarIconButton (like the built-in bar widgets) so the icon sits in the
  // standard icon slot with the same spacing as its neighbours.
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: castIconComponent
    active: root.casting
    tooltipText: root.casting ? "Casting to " + (root.receiverName || "receiver") : "Cast · Screen and Media"
    onPressed: function(b) { if (b === Qt.LeftButton) root.toggle() }
    Rectangle {
      visible: root.casting
      width: Style.space(5); height: width; radius: width / 2
      color: Color.accent
      anchors.right: parent.right; anchors.bottom: parent.bottom
      anchors.margins: Style.space(2)
    }
  }

  // While casting, the glyph takes the bar's active colour (the same one the
  // microphone widget uses while in use) instead of the plain foreground, so an
  // ongoing cast is visible at a glance; idle stays dimmed.
  Component {
    id: castIconComponent
    CastIcon {
      active: root.casting
      foreground: root.casting ? button.activeColor : Qt.darker(root.foreground, 1.28)
    }
  }

  // Cast glyph on a Canvas: a screen with the signal waves INSIDE its
  // lower-left corner. Sized by its parent (the icon canvas), no fixed size.
  component CastIcon: Canvas {
    id: icon
    property bool active: false
    property color foreground: "white"
    onActiveChanged: requestPaint()
    onForegroundChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var w = width, h = height
      ctx.lineWidth = Math.max(1.25, w * 0.075)
      ctx.lineCap = "round"
      ctx.lineJoin = "round"
      ctx.strokeStyle = icon.foreground
      var x0 = w * 0.13, y0 = h * 0.16, x1 = w * 0.87, y1 = h * 0.74
      var rr = Math.min(w, h) * 0.10
      ctx.beginPath()
      ctx.moveTo(x0 + rr, y0)
      ctx.lineTo(x1 - rr, y0); ctx.arcTo(x1, y0, x1, y0 + rr, rr)
      ctx.lineTo(x1, y1 - rr); ctx.arcTo(x1, y1, x1 - rr, y1, rr)
      ctx.lineTo(x0 + rr, y1); ctx.arcTo(x0, y1, x0, y1 - rr, rr)
      ctx.lineTo(x0, y0 + rr); ctx.arcTo(x0, y0, x0 + rr, y0, rr)
      ctx.stroke()
      var cx = w * 0.24, cy = h * 0.63
      ctx.beginPath(); ctx.arc(cx, cy, w * 0.14, -Math.PI / 2, 0); ctx.stroke()
      ctx.beginPath(); ctx.arc(cx, cy, w * 0.26, -Math.PI / 2, 0); ctx.stroke()
      ctx.fillStyle = icon.foreground
      ctx.beginPath(); ctx.arc(cx, cy, Math.max(1.0, w * 0.045), 0, 2 * Math.PI); ctx.fill()
    }
  }
}

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Layout.js" as Logic

Panel {
  id: root
  // Based on the MIT-licensed Omarchy Display Layout plugin, adapted for
  // Strata's menu-launched Display panel and Hyprland Lua configuration.
  moduleName: "strata.monitor"
  manageIpc: false
  property var shell: null
  property var manifest: null

  // `live` is what Hyprland uses right now, `arrangement` is what the canvas
  // shows. They differ while the user has moved tiles without applying.
  property var live: []
  property var arrangement: []
  property string monitorsJson: ""
  property string configText: ""
  property int selected: 0
  property string lastSide: ""
  property int alignIndex: 0
  property string error: ""
  property bool identifying: false
  property int brightness: 100
  property bool brightnessAvailable: false
  property bool brightnessPending: false
  property var brightnessByMonitor: ({})
  property string brightnessReadMonitorName: ""
  property int textSize: 12
  property bool textSizeLoaded: false
  // Refresh the editor after HDMI, DisplayPort, USB-C, or dock hotplug events.
  property int connectedScreenCount: Quickshell.screens.length

  readonly property var alignments: ["center", "start", "end"]
  readonly property var rotations: ["", "rotated 90°", "upside down", "rotated 270°"]
  // Keep the same useful major scale steps as Omarchy's Display panel.
  readonly property var scaleValues: [1, 1.25, 1.6, 2, 3, 4]
  // Each display has its own workspace cycle, managed independently of layout.
  readonly property bool pinWorkspaces: false
  readonly property bool changed: !Logic.sameLayout(arrangement, live)
  readonly property bool saved: Logic.isSaved(configText, live, pinWorkspaces)
  readonly property bool busy: applyProcess.running || saveProcess.running
  readonly property var current: arrangement[selected] || null
  readonly property int enabledCount: arrangement.filter(function(m) { return !m.disabled }).length

  readonly property string pluginPath: decodeURIComponent(
    Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")
  )
  readonly property string configPath: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config")
    + "/hypr/monitors.lua"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string statusText: {
    if (arrangement.length === 0) return "No displays"
    if (changed) return "Not applied yet"
    if (!saved) return "Applied · not saved"
    return "Saved"
  }

  readonly property string currentTitle: {
    var m = current
    if (!m) return ""
    var label = /^(eDP|LVDS|DSI)/.test(m.name) ? "Built-in display" : m.model !== "" ? m.model : m.description
    return labelOf(selected) + " · " + m.name + (label !== "" ? " · " + label : "")
  }

  readonly property string currentDetails: {
    var m = current
    if (!m) return ""
    if (m.disabled) return "Off"
    if (m.mirrorOf) return "Mirrors " + m.mirrorOf
    return m.width + "×" + m.height + " @ " + Math.round(m.refreshRate) + " Hz"
      + (m.scale !== 1 ? " · scale " + m.scale : "")
      + (m.transform ? " · " + rotations[m.transform % 4] : "")
      + " · at " + m.x + "×" + m.y
  }

  function refresh() {
    if (!monitorsProcess.running) monitorsProcess.running = true
    configFile.reload()
  }

  // Edits that are not applied yet survive a refresh, anything else follows
  // what Hyprland reports.
  function rebuild(rulesJson) {
    var hadEdits = changed
    var parsed = Logic.parseMonitors(monitorsJson)
    live = pinWorkspaces ? Logic.withPinned(parsed, rulesJson) : parsed
    if (!hadEdits || arrangement.length !== live.length) arrangement = Logic.copy(live)
    selected = Math.max(0, Math.min(selected, arrangement.length - 1))
    refreshDisplaySettings(false)
  }

  // Hardware brightness reads can take a while, especially over DDC. Show
  // cached values at selection time and ignore results from another display.
  function refreshDisplaySettings(force) {
    // `onSelectedChanged` runs before the `current` binding has necessarily
    // reevaluated, so resolve the selected row directly here.
    var monitor = arrangement[selected]
    var name = monitor ? monitor.name : ""
    if (!opened || name === "") return
    var cached = brightnessByMonitor[name]
    brightnessAvailable = cached !== undefined && cached.available
    brightnessPending = cached === undefined
    if (brightnessAvailable) brightness = cached.value
    if ((force || cached === undefined) && !brightnessReadProcess.running) {
      brightnessReadMonitorName = name
      brightnessReadProcess.command = ["strata-brightness-display", "--monitor", name]
      brightnessReadProcess.running = true
    }
    if (!textSizeLoaded && !textSizeReadProcess.running) textSizeReadProcess.running = true
  }

  function setBrightness(value) {
    if (!current || brightnessSetProcess.running) return
    brightness = Math.max(1, Math.min(100, Math.round(value)))
    var updated = Object.assign({}, brightnessByMonitor)
    updated[current.name] = { available: true, value: brightness }
    brightnessByMonitor = updated
    brightnessSetProcess.command = ["strata-brightness-display", "--monitor", current.name, brightness + "%"]
    brightnessSetProcess.running = true
  }

  function setTextSize(value) {
    if (textSizeSetProcess.running) return
    textSize = Math.max(9, Math.min(20, Math.round(value)))
    textSizeSetProcess.command = ["strata-display-text-size", String(textSize)]
    textSizeSetProcess.running = true
  }

  // The number a display goes by: its workspace, or its position in the list
  // when workspace numbers are not managed here.
  function labelOf(index) {
    var m = arrangement[index]
    if (!m) return ""
    return pinWorkspaces && m.workspace > 0 ? String(m.workspace) : String(index + 1)
  }

  function select(index) {
    if (index < 0 || index >= arrangement.length) return
    selected = index
    lastSide = ""
  }

  function selectLabel(label) {
    for (var i = 0; i < arrangement.length; i++) if (labelOf(i) === label) return select(i)
  }

  function rotate() {
    if (!current) return
    lastSide = ""
    arrangement = Logic.rotate(arrangement, selected)
  }

  function setCurrentScale(scale) {
    if (!current) return
    arrangement = Logic.setScale(arrangement, selected, scale)
  }

  function refreshRatesForCurrent() {
    return current ? Logic.refreshRates(current, current.width, current.height) : []
  }

  function setCurrentResolution(width, height) {
    if (!current) return
    arrangement = Logic.setResolution(arrangement, selected, width, height)
  }

  function refreshLabel(rate) {
    return (Math.abs(rate - Math.round(rate)) < 0.05 ? Math.round(rate) : rate.toFixed(2)) + "Hz"
  }

  function setCurrentRefreshRate(rate) {
    if (!current) return
    arrangement = Logic.setRefreshRate(arrangement, selected, rate)
  }

  function mainMonitor() {
    for (var i = 0; i < arrangement.length; i++) {
      var m = arrangement[i]
      if (!m.disabled && !m.mirrorOf && m.x === 0 && m.y === 0) return m
    }
    for (var j = 0; j < arrangement.length; j++) {
      if (!arrangement[j].disabled && !arrangement[j].mirrorOf) return arrangement[j]
    }
    return null
  }

  function makeMain() {
    if (!current || current.disabled) return
    var out = Logic.copy(arrangement)
    out[selected].mirrorOf = ""
    out[selected].x = 0
    out[selected].y = 0
    var nextX = out[selected].w
    for (var i = 0; i < out.length; i++) {
      if (i === selected || out[i].disabled || out[i].mirrorOf) continue
      out[i].x = nextX
      out[i].y = 0
      nextX += out[i].w
    }
    arrangement = out
  }

  function mirrorCurrent() {
    var main = mainMonitor()
    if (!current || !main || main.name === current.name) return
    arrangement = Logic.setMirror(arrangement, selected, main.name)
  }

  function extendCurrent() {
    if (!current) return
    var out = Logic.setExtended(arrangement, selected)
    var right = 0
    for (var i = 0; i < out.length; i++) {
      if (i !== selected && !out[i].disabled && !out[i].mirrorOf) right = Math.max(right, out[i].x + out[i].w)
    }
    out[selected].x = right
    out[selected].y = 0
    arrangement = out
  }

  function setCurrentEnabled(enabled) {
    if (!current || (!enabled && enabledCount <= 1)) return
    arrangement = Logic.setEnabled(arrangement, selected, enabled)
  }

  // Arrow keys and the side buttons: the first press moves the selected
  // display to that side, repeated presses walk it along the edge.
  function moveTo(side) {
    if (arrangement.length < 2 || !current) return
    alignIndex = side === lastSide ? (alignIndex + 1) % alignments.length : 0
    lastSide = side
    arrangement = Logic.place(arrangement, selected, side, alignments[alignIndex])
  }

  function lineUp() {
    lastSide = ""
    arrangement = Logic.row(arrangement, "center")
  }

  function discard() {
    lastSide = ""
    arrangement = Logic.copy(live)
  }

  // Live only: Hyprland forgets this on the next reload until it is saved.
  function apply() {
    if (busy || arrangement.length === 0) return
    error = ""
    applyProcess.command = ["hyprctl", "eval", Logic.liveScript(configText, arrangement, live, pinWorkspaces)]
    applyProcess.running = true
  }

  function save() {
    if (busy || arrangement.length === 0) return
    error = ""
    saveProcess.command = [
      "strata-save-display-layout",
      Logic.updateConfig(configText, arrangement, pinWorkspaces),
      pinWorkspaces ? Logic.workspaceMoves(arrangement, live) : ""
    ]
    saveProcess.running = true
  }

  function identify() {
    identifying = true
    identifyTimer.restart()
  }

  function labelOfScreen(name) {
    for (var i = 0; i < arrangement.length; i++) if (arrangement[i].name === name) return labelOf(i)
    return ""
  }

  onOpenedChanged: {
    if (opened) {
      viewport.contentY = 0
      error = ""
      lastSide = ""
      brightnessByMonitor = ({})
      brightnessAvailable = false
      brightnessPending = false
      textSizeLoaded = false
      arrangement = Logic.copy(live)
      refresh()
    } else if (shell) shell.hide(root.moduleName)
  }

  onConnectedScreenCountChanged: hotplugSettle.restart()
  onSelectedChanged: refreshDisplaySettings(false)

  Process {
    id: monitorsProcess
    command: ["hyprctl", "monitors", "all", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.monitorsJson = text
        if (root.pinWorkspaces) rulesProcess.running = true
        else root.rebuild("")
      }
    }
  }

  Process {
    id: rulesProcess
    command: ["hyprctl", "workspacerules", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.rebuild(text)
    }
  }

  Process {
    id: applyProcess
    // hyprctl reports a rejected eval on stdout
    stdout: StdioCollector { id: applyOutput; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.error = String(applyOutput.text).trim() || "Hyprland did not accept the layout"
      settleTimer.restart()
    }
  }

  Process {
    id: saveProcess
    stderr: StdioCollector { id: saveErrors; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.error = String(saveErrors.text).trim() || "Could not save monitors.lua"
      settleTimer.restart()
    }
  }

  Process {
    id: brightnessReadProcess
    stdout: StdioCollector {
      id: brightnessReadOutput
      waitForEnd: true
    }
    onExited: function(exitCode) {
      var value = Math.round(Number(String(brightnessReadOutput.text).trim()))
      var available = exitCode === 0 && value >= 1 && value <= 100
      var updated = Object.assign({}, root.brightnessByMonitor)
      updated[root.brightnessReadMonitorName] = { available: available, value: value }
      root.brightnessByMonitor = updated
      var selectedMonitor = root.arrangement[root.selected]
      if (selectedMonitor && selectedMonitor.name === root.brightnessReadMonitorName) {
        root.brightnessAvailable = available
        root.brightnessPending = false
        if (available) root.brightness = value
      }
      brightnessReadNext.start()
    }
  }

  Timer {
    id: brightnessReadNext
    interval: 0
    onTriggered: root.refreshDisplaySettings(false)
  }

  Process { id: brightnessSetProcess }

  Process {
    id: textSizeReadProcess
    command: ["strata-display-text-size"]
    stdout: StdioCollector {
      id: textSizeReadOutput
      waitForEnd: true
    }
    onExited: {
      var match = String(textSizeReadOutput.text).match(/text size:\s*(\d+)/)
      if (match) root.textSize = Math.max(9, Math.min(20, Number(match[1])))
      root.textSizeLoaded = true
    }
  }

  Process { id: textSizeSetProcess }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.configText = text()
    onLoadFailed: root.configText = ""
  }

  // Hyprland needs a moment to move the outputs before it reports them
  Timer {
    id: settleTimer
    interval: 350
    onTriggered: root.refresh()
  }

  Timer {
    id: hotplugSettle
    interval: 900
    repeat: false
    onTriggered: root.refresh()
  }

  // Some display drivers update Hyprland before they notify Quickshell about
  // the new Wayland output. Poll Hyprland directly so the editor detects
  // HDMI, DP, USB-C and dock changes even while this popup is closed.
  Timer {
    id: monitorStatePoll
    interval: 2000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Timer {
    id: identifyTimer
    interval: 2500
    onTriggered: root.identifying = false
  }

  // ---------- Number badges on the real screens ----------
  Variants {
    model: root.identifying ? Quickshell.screens : []

    PanelWindow {
      id: badge
      required property var modelData
      readonly property string label: root.labelOfScreen(modelData.name)

      screen: modelData
      visible: label !== ""
      anchors { top: true; left: true }
      margins { top: Style.space(48); left: Style.space(48) }
      implicitWidth: badgeCard.width
      implicitHeight: badgeCard.height
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "strata-display-layout"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      mask: Region {}

      Rectangle {
        id: badgeCard
        width: badgeColumn.implicitWidth + Style.space(56)
        height: badgeColumn.implicitHeight + Style.space(32)
        radius: Style.cornerRadius
        color: Util.alpha(Color.background, 0.95)
        border.width: Math.max(1, Style.space(2))
        border.color: Color.accent

        Column {
          id: badgeColumn
          anchors.centerIn: parent
          spacing: Style.space(4)

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: badge.label
            color: Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.displayLarge * 3
            font.bold: true
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: badge.modelData.name
            color: Color.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
          }
        }
      }
    }
  }

  KeyboardPanel {
    id: panel
    panelHeader: panelTitleHeader
    standalone: true
    anchorItem: null
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(460))
    contentHeight: panel.fittedContentHeight(viewport.contentHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        root.moveTo(dx < 0 ? "left" : dx > 0 ? "right" : dy < 0 ? "top" : "bottom")
      }
      onActivateRequested: {
        if (root.changed) root.apply()
        else if (!root.saved) root.save()
      }
      onCloseRequested: root.close()
      onTextKey: function(text) {
        if (text >= "0" && text <= "9") root.selectLabel(text === "0" ? "10" : text)
        else if (text === "t") root.rotate()
        else if (text === "i") root.identify()
        else if (text === "r") root.lineUp()
        else if (text === "u") root.discard()
      }

      Flickable {
        id: viewport
        objectName: "displayLayoutViewport"
        readonly property int controlInset: Math.max(1, Style.space(2))
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: column.implicitHeight + controlInset * 2
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        onHeightChanged: returnToBounds()
        ScrollBar.vertical: PanelScrollBar {
          id: scrollBar
          foreground: root.foreground
          parent: viewport.parent
          anchors.top: viewport.top
          anchors.bottom: viewport.bottom
          anchors.right: viewport.right
          anchors.rightMargin: Style.space(4) - panel.padding
        }
      }

      Column {
        id: column
        parent: viewport.contentItem
        x: viewport.controlInset
        y: viewport.controlInset
        width: Math.max(0, viewport.width - viewport.controlInset * 2)
        spacing: Style.space(12)

        // ---------- Hero: icon · title/status · actions ----------
        PanelHeaderSurface {
          id: panelTitleHeader
          parent: panel.headerContainer
          width: parent.width
          headerForeground: root.foreground
          implicitHeight: Style.space(58)


          Column {
            id: heroLabels
            anchors.left: parent.left
            anchors.leftMargin: Style.space(16)
            anchors.right: heroActions.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Display Layout"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: root.statusText
              color: root.changed ? root.urgent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption

              elide: Text.ElideRight
              width: parent.width
            }
          }

          Row {
            id: heroActions
            anchors.right: parent.right
            anchors.rightMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            PanelActionButton {
              iconText: "󰎠"
              tooltipText: "Show each display's number on its screen (i)"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.identify()
            }

            PanelActionButton {
              visible: root.arrangement.length > 1
              iconText: "󰡎"
              tooltipText: "Line all displays up in a row (r)"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.lineUp()
            }

            PanelActionButton {
              enabled: root.changed
              opacity: enabled ? 1 : 0.35
              iconText: "󰕌"
              tooltipText: "Undo the changes that are not applied (u)"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.discard()
            }
          }

        }

        // ---------- Canvas ----------
        Rectangle {
          id: canvas
          width: parent.width
          height: Style.space(190)
          radius: Style.cornerRadius
          color: Util.alpha(root.foreground, 0.04)
          border.width: 1
          border.color: Util.alpha(root.foreground, 0.12)
          clip: true

          // The view only follows the committed arrangement, so the scale
          // stays put while a tile is being dragged around.
          readonly property var box: Logic.bounds(root.arrangement)
          readonly property real k: Math.min(width * 0.9 / box.w, height * 0.7 / box.h)
          readonly property real ox: (width - box.w * k) / 2 - box.x * k
          readonly property real oy: (height - box.h * k) / 2 - box.y * k

          Repeater {
            model: root.arrangement.length

            Rectangle {
              id: tile
              required property int index
              readonly property var m: root.arrangement[index] || ({ x: 0, y: 0, w: 1, h: 1, name: "" })
              readonly property bool isSelected: root.selected === index
              property bool dragging: false
              property real dragX: 0
              property real dragY: 0
              property real dropX: 0
              property real dropY: 0

              x: dragging ? dragX : canvas.ox + m.x * canvas.k
              y: dragging ? dragY : canvas.oy + m.y * canvas.k
              width: m.w * canvas.k
              height: m.h * canvas.k
              z: dragging ? 2 : isSelected ? 1 : 0
              radius: Math.min(Style.cornerRadius, Style.space(4))
              color: isSelected ? Style.selectedAccentFill : Util.alpha(root.foreground, grab.containsMouse ? 0.14 : 0.08)
              border.width: isSelected ? 2 : 1
              border.color: isSelected ? Color.accent : Util.alpha(root.foreground, 0.4)

              Behavior on x { enabled: !tile.dragging; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
              Behavior on y { enabled: !tile.dragging; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

              Column {
                anchors.centerIn: parent
                width: parent.width - Style.space(6)
                spacing: Style.space(1)

                Text {
                  width: parent.width
                  horizontalAlignment: Text.AlignHCenter
                  text: root.labelOf(tile.index)
                  color: tile.isSelected ? Color.accent : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                }

                Text {
                  width: parent.width
                  visible: tile.height > Style.space(34) && tile.width > Style.space(56)
                  horizontalAlignment: Text.AlignHCenter
                  textFormat: Text.PlainText
                  text: tile.m.name
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }

              MouseArea {
                id: grab
                anchors.fill: parent
                preventStealing: true
                hoverEnabled: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property real grabX: 0
                property real grabY: 0
                property bool moved: false

                onPressed: function(mouse) {
                  root.select(tile.index)
                  var p = mapToItem(canvas, mouse.x, mouse.y)
                  grabX = p.x - tile.x
                  grabY = p.y - tile.y
                  moved = false
                }

                onPositionChanged: function(mouse) {
                  if (!pressed) return
                  var p = mapToItem(canvas, mouse.x, mouse.y)
                  var px = p.x - grabX
                  var py = p.y - grabY
                  if (!moved && Math.abs(px - tile.x) + Math.abs(py - tile.y) < Style.space(4)) return

                  var spot = Logic.snap(
                    root.arrangement, tile.index,
                    (px - canvas.ox) / canvas.k, (py - canvas.oy) / canvas.k,
                    Style.space(12) / canvas.k
                  )
                  tile.dropX = spot.x
                  tile.dropY = spot.y
                  tile.dragX = canvas.ox + spot.x * canvas.k
                  tile.dragY = canvas.oy + spot.y * canvas.k
                  tile.dragging = true
                  moved = true
                }

                onReleased: {
                  if (!moved) return
                  root.arrangement = Logic.move(root.arrangement, tile.index, tile.dropX, tile.dropY)
                  tile.dragging = false
                }

                onCanceled: tile.dragging = false
              }
            }
          }

          Text {
            anchors.centerIn: parent
            visible: root.arrangement.length === 0
            text: "No active display found"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
        }

        // Settings always follow the selected preview tile.
        Column {
          width: parent.width
          visible: root.current !== null
          spacing: Style.space(14)

          Item {
            width: parent.width
            implicitHeight: Math.max(displayLabels.implicitHeight, displayPower.implicitHeight)

            Column {
              id: displayLabels
              anchors.left: parent.left
              anchors.right: displayPower.left
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(4)

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: root.currentTitle
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: root.currentDetails
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
              }
            }

            ToggleSwitch {
              id: displayPower
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              foreground: root.foreground
              checked: root.current !== null && !root.current.disabled
              enabled: root.current !== null && (root.current.disabled || root.enabledCount > 1)
              opacity: enabled ? 1 : 0.45
              onToggled: root.setCurrentEnabled(root.current.disabled)

              PanelToolTip {
                visible: displayPower.containsMouse
                text: !displayPower.enabled ? "Keep at least one display enabled"
                  : displayPower.checked ? "Turn off this display" : "Turn on this display"
              }
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "DISPLAY MODE"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Row {
              width: parent.width
              spacing: Style.space(6)

              Button {
                width: (parent.width - parent.spacing) / 2
                text: "Extend"
                iconText: "󰕰"
                selected: root.current && !root.current.disabled && root.current.mirrorOf === ""
                enabled: root.current && !root.current.disabled
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                bordered: true
                tooltipText: "Use this display as its own extended desktop"
                onClicked: root.extendCurrent()
              }

              Button {
                width: (parent.width - parent.spacing) / 2
                text: "Mirror"
                iconText: "󰍺"
                selected: root.current && root.current.mirrorOf !== ""
                enabled: root.current && root.mainMonitor() !== null && root.mainMonitor().name !== root.current.name
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                bordered: true
                tooltipText: "Mirror the main display on this display"
                onClicked: root.mirrorCurrent()
              }
            }

            Button {
              width: parent.width
              text: selected ? "Main display" : "Make main display"
              iconText: "󰘔"
              selected: root.current && !root.current.disabled && !root.current.mirrorOf
                && root.current.x === 0 && root.current.y === 0
              enabled: root.current && !root.current.disabled
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              bordered: true
              tooltipText: "Make this the main display and place the other displays beside it"
              onClicked: root.makeMain()
            }
          }

          PanelSeparator { foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "APPEARANCE"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Column {
              width: parent.width
              visible: root.current !== null
              spacing: Style.space(2)

              Item {
                width: parent.width
                height: Style.space(18)

                Text {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Brightness"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                Text {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.brightnessPending ? "Loading…"
                    : root.brightnessAvailable
                      ? Math.round(brightnessSlider.dragging ? brightnessSlider.liveValue : root.brightness) + "%"
                      : "Unavailable"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }

              PanelSlider {
                id: brightnessSlider
                width: parent.width
                visible: root.brightnessAvailable && !root.brightnessPending
                bar: root.bar
                minimum: 1
                maximum: 100
                step: 1
                integer: true
                value: root.brightness
                tickCount: 0
                onReleased: function(value) { root.setBrightness(value) }
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(2)

              Item {
                width: parent.width
                height: Style.space(18)

                Text {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Text size"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                Text {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: Math.round(textSizeSlider.dragging ? textSizeSlider.liveValue : root.textSize) + "px"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }

              PanelSlider {
                id: textSizeSlider
                width: parent.width
                bar: root.bar
                minimum: 9
                maximum: 20
                step: 1
                integer: true
                value: root.textSize
                tickCount: 12
                onReleased: function(value) { root.setTextSize(value) }
              }
            }

          }

          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "RESOLUTION"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Dropdown {
              id: resolutionPicker
              objectName: "displayResolutionPicker"
              width: parent.width
              showLabel: false
              foreground: root.foreground
              fontFamily: root.fontFamily
              updateValueOnSelection: false
              value: root.current ? root.current.width + "x" + root.current.height : ""
              options: Logic.resolutions(root.current).map(function(mode) {
                return { value: mode.width + "x" + mode.height,
                  label: mode.width + " × " + mode.height }
              })
              onChanged: function(value) {
                var dimensions = value.split("x")
                root.setCurrentResolution(Number(dimensions[0]), Number(dimensions[1]))
              }
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "DISPLAY SCALE"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Row {
              width: parent.width
              spacing: Style.space(4)

              Repeater {
                model: root.scaleValues

                Button {
                  required property real modelData
                  width: (parent.width - parent.spacing * (root.scaleValues.length - 1)) / root.scaleValues.length
                  text: modelData + "×"
                  selected: root.current !== null && Math.abs(root.current.scale - modelData) < 0.01
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  fontSize: Style.font.caption
                  horizontalPadding: Style.space(3)
                  verticalPadding: Style.space(5)
                  bordered: true
                  onClicked: root.setCurrentScale(modelData)
                }
              }
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "REFRESH RATE"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Flow {
              width: parent.width
              spacing: Style.space(5)

              Repeater {
                model: root.refreshRatesForCurrent()

                Button {
                  required property real modelData
                  text: root.refreshLabel(modelData)
                  selected: root.current !== null && Math.abs(root.current.refreshRate - modelData) < 0.05
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  fontSize: Style.font.caption
                  horizontalPadding: Style.space(10)
                  verticalPadding: Style.space(5)
                  bordered: true
                  onClicked: root.setCurrentRefreshRate(modelData)
                }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "POSITION & ROTATION"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Item {
              width: parent.width
              implicitHeight: Math.max(sideButtons.implicitHeight, rotateButton.implicitHeight)

              Row {
                id: sideButtons
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(5)
                visible: root.arrangement.length > 1

                Repeater {
                  model: [
                    { side: "left", icon: "󰁍", tip: "Move to the left of the others" },
                    { side: "top", icon: "󰁝", tip: "Move above the others" },
                    { side: "bottom", icon: "󰁅", tip: "Move below the others" },
                    { side: "right", icon: "󰁔", tip: "Move to the right of the others" }
                  ]

                  PanelActionButton {
                    required property var modelData
                    iconText: modelData.icon
                    tooltipText: modelData.tip + "\nPress again to slide along the edge"
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    bordered: true
                    onClicked: root.moveTo(modelData.side)
                  }
                }
              }

              Button {
                id: rotateButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰑧"
                text: "Rotate"
                tooltipText: "Turn this display by 90° (t)"
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                verticalPadding: Style.space(5)
                bordered: true
                onClicked: root.rotate()
              }
            }
          }
        }

        Text {
          width: parent.width
          visible: root.error !== ""
          textFormat: Text.PlainText
          text: root.error
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
          maximumLineCount: 4
          elide: Text.ElideRight
        }

        PanelSeparator { foreground: root.foreground }

        // ---------- Apply / Save ----------
        Row {
          width: parent.width
          spacing: Style.space(8)

          Button {
            width: (parent.width - parent.spacing) / 2
            enabled: root.changed && !root.busy
            opacity: enabled ? 1 : 0.4
            iconText: "󰄬"
            text: "Apply"
            tooltipText: "Try the layout now. It lasts until Hyprland reloads."
            foreground: root.foreground
            fontFamily: root.fontFamily
            bordered: true
            onClicked: root.apply()
          }

          Button {
            width: (parent.width - parent.spacing) / 2
            enabled: (root.changed || !root.saved) && !root.busy && root.arrangement.length > 0
            opacity: enabled ? 1 : 0.4
            iconText: "󰆓"
            text: "Save"
            tooltipText: "Write the layout to ~/.config/hypr/monitors.lua.\nThe previous file is kept as a backup."
            foreground: root.foreground
            fontFamily: root.fontFamily
            bordered: true
            onClicked: root.save()
          }
        }

        Text {
          width: parent.width
          text: "Drag the preview to arrange · Enter to apply"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
        }
      }
    }
  }
}

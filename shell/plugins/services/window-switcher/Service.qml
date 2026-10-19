import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "Model.js" as Model

// Inspired by lsongdev/omarchy-switcher (MIT):
// https://github.com/lsongdev/omarchy-switcher
Item {
  id: root

  property var shell: null
  property bool opened: false
  property real reveal: 0
  property var windows: []
  property int selectedIndex: 0
  property int hoveredIndex: -1
  property int pendingSteps: 0
  property bool queryWanted: false
  property bool commitWhenReady: false
  property bool overviewWanted: false
  property bool awaitingStage: false
  property bool previewDelayElapsed: false
  property bool altProbeWanted: false
  property string lastInput: ""
  property var targetScreen: null
  readonly property var stageService: shell && typeof shell.serviceFor === "function"
    ? shell.serviceFor("strata.stage-control") : null
  readonly property color selectionColor: stageService ? stageService.highlight : Color.accent

  readonly property int cardWidth: Math.min(Style.space(320), Math.max(Style.space(180), overlay.width - Style.space(60)))
  readonly property int cardHeight: Style.space(214)
  readonly property int cardPadding: Style.space(8)
  readonly property int overviewColumns: Math.max(1, Math.min(windows.length, 4,
    Math.floor((overlay.width - Style.space(80)) / (cardWidth + Style.space(20)))))

  onOpenedChanged: {
    if (opened) entrance.restart()
    else {
      entrance.stop()
      reveal = 0
    }
  }

  NumberAnimation {
    id: entrance
    target: root
    property: "reveal"
    from: 0
    to: 1
    duration: 280
    easing.type: Easing.OutCubic
  }

  function focusedScreen() {
    var monitorName = Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name || "") : ""
    var screens = Quickshell.screens || []
    for (var i = 0; i < screens.length; i++)
      if (String(screens[i].name || "") === monitorName) return screens[i]
    return screens.length ? screens[0] : null
  }

  function dismissStageNow() {
    if (!stageService) return
    // A quick app switch must not leave the full-screen Stage over its target.
    if (stageService.shown) stageService.finishClose()
    else stageService.close({})
  }

  function cycle(direction) {
    dismissStageNow()
    if (opened && windows.length) {
      select(direction)
      return
    }
    if (windows.length && !queryWanted) {
      selectedIndex = Model.selectedIndex(selectedIndex + direction, windows.length)
      return
    }
    if (!queryWanted) {
      targetScreen = focusedScreen()
      previewDelayElapsed = false
      previewDelay.restart()
    }
    pendingSteps += direction
    queryWanted = true
    overviewWanted = false
    if (!clientsQuery.running) clientsQuery.running = true
  }

  function gestureSwitch(direction) {
    dismissStageNow()
    if (opened && windows.length) {
      select(direction)
      commit()
      return
    }
    if (windows.length && !queryWanted) {
      selectedIndex = Model.selectedIndex(selectedIndex + direction, windows.length)
      commit()
      return
    }
    if (!queryWanted) targetScreen = focusedScreen()
    pendingSteps += direction
    queryWanted = true
    commitWhenReady = true
    overviewWanted = false
    if (!clientsQuery.running) clientsQuery.running = true
  }

  function toggleOverview() {
    if (opened) { cancel(); return }
    if (awaitingStage) { cancel(); return }
    if (stageService && stageService.shown) {
      awaitingStage = true
      stageService.close({})
      return
    }
    if (stageService) stageService.close({})
    startOverview()
  }

  function startOverview() {
    previewDelay.stop()
    previewDelayElapsed = true
    targetScreen = focusedScreen()
    pendingSteps = 0
    queryWanted = true
    commitWhenReady = false
    overviewWanted = true
    if (!clientsQuery.running) clientsQuery.running = true
  }

  function select(direction) {
    selectedIndex = Model.selectedIndex(selectedIndex + direction, windows.length)
    Qt.callLater(function() {
      if (!opened) return
      overviewGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
    })
  }

  function cancel() {
    awaitingStage = false
    previewDelay.stop()
    altProbeWanted = false
    previewDelayElapsed = false
    opened = false
    windows = []
    hoveredIndex = -1
    pendingSteps = 0
    queryWanted = false
    commitWhenReady = false
    overviewWanted = false
  }

  function focusWindow(address) {
    if (!address) return
    Qt.callLater(function() {
      Quickshell.execDetached([
        "hyprctl", "eval",
        'hl.dispatch(hl.dsp.focus({ window = "address:' + address + '" }))'
      ])
    })
  }

  function commit() {
    previewDelay.stop()
    if (queryWanted && !opened) {
      // A quick Alt+Tab can release Alt before hyprctl returns its snapshot.
      commitWhenReady = true
      return
    }
    if (selectedIndex < 0 || selectedIndex >= windows.length) {
      cancel()
      return
    }
    var address = windows[selectedIndex].address
    cancel()
    focusWindow(address)
  }

  function showOverlay() {
    if (opened || !windows.length) return
    opened = true
    Qt.callLater(function() {
      if (!opened) return
      keyCatcher.forceActiveFocus()
      overviewGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
    })
  }

  Timer {
    id: previewDelay
    interval: 180
    onTriggered: {
      // A quick Alt+Tab may have released Alt before its release event reaches
      // the shell. Never open a keyboard-grabbing layer after that release.
      root.altProbeWanted = true
      if (!altProbe.running) altProbe.running = true
    }
  }

  Process {
    id: altProbe
    command: ["hyprctl", "repl", 'return tostring(hl.is_key_down("Alt_L") or hl.is_key_down("Alt_R"))']
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!root.altProbeWanted) return
        root.altProbeWanted = false
        if (String(text).trim() !== "true") {
          root.commit()
          return
        }
        root.previewDelayElapsed = true
        if (!root.queryWanted) root.showOverlay()
      }
    }
  }

  function finishWindowQuery(raw) {
    if (!queryWanted) return
    var clients
    try {
      clients = JSON.parse(String(raw || "[]"))
    } catch (e) {
      console.warn("strata.window-switcher: could not parse Hyprland clients:", e)
      cancel()
      return
    }
    var tops = Hyprland.toplevels && Hyprland.toplevels.values ? Hyprland.toplevels.values : []
    var next = Model.snapshotWindows(clients, tops)
    if (next.length < (overviewWanted ? 1 : 2)) {
      console.warn("strata.window-switcher: no eligible windows in Hyprland snapshot:", clients.length, "clients,", next.length, "eligible")
      cancel()
      return
    }
    var index = Model.selectedIndex(pendingSteps, next.length)
    var quickCommit = commitWhenReady
    var showImmediately = overviewWanted
    pendingSteps = 0
    queryWanted = false
    commitWhenReady = false
    overviewWanted = false
    if (quickCommit) {
      cancel()
      focusWindow(next[index].address)
      return
    }
    windows = next
    selectedIndex = index
    hoveredIndex = -1
    if (showImmediately || previewDelayElapsed) showOverlay()
  }

  Process {
    id: clientsQuery
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.finishWindowQuery(text)
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (!event || event.name !== "custom") return
      var data = String(event.data || "")
      if (data.indexOf("strata.window-switcher|") !== 0) return
      root.lastInput = data.slice("strata.window-switcher|".length)
      if (data === "strata.window-switcher|next") root.cycle(1)
      else if (data === "strata.window-switcher|previous") root.cycle(-1)
      else if (data === "strata.window-switcher|commit") root.commit()
      else if (data === "strata.window-switcher|dismiss") root.cancel()
    }
  }

  Connections {
    target: root.stageService
    function onShownChanged() {
      if (!root.stageService.shown && root.awaitingStage) {
        root.awaitingStage = false
        root.startOverview()
      }
    }
  }

  GlobalShortcut {
    appid: "strata.window-switcher"
    name: "next"
    description: "Show next window"
    onPressed: root.cycle(1)
  }
  GlobalShortcut {
    appid: "strata.window-switcher"
    name: "previous"
    description: "Show previous window"
    onPressed: root.cycle(-1)
  }
  GlobalShortcut {
    appid: "strata.window-switcher"
    name: "commit"
    description: "Switch to selected window"
    onPressed: root.commit()
  }
  GlobalShortcut {
    appid: "strata.window-switcher"
    name: "gesture-next"
    description: "Switch to next app with touchpad"
    onPressed: root.gestureSwitch(1)
  }
  GlobalShortcut {
    appid: "strata.window-switcher"
    name: "gesture-previous"
    description: "Switch to previous app with touchpad"
    onPressed: root.gestureSwitch(-1)
  }
  GlobalShortcut {
    appid: "strata.window-switcher"
    name: "overview"
    description: "Show all windows with touchpad"
    onPressed: root.toggleOverview()
  }

  IpcHandler {
    target: "strata-window-switcher"
    function overview(): string { root.toggleOverview(); return "ok" }
    function close(): string { root.cancel(); return "ok" }
    function status(): string {
      return JSON.stringify({ opened: root.opened, querying: root.queryWanted,
        windows: root.windows.length, previewWaiting: previewDelay.running,
        lastInput: root.lastInput })
    }
  }

  PanelWindow {
    id: overlay
    visible: root.opened
    screen: root.targetScreen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "strata-window-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    onVisibleChanged: if (visible) keyCatcher.forceActiveFocus()

    Image {
      id: stageWallpaper
      anchors.fill: parent
      source: root.stageService ? root.stageService.wallpaperUrl : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: true
      smooth: true
      visible: true
    }

    MultiEffect {
      anchors.fill: parent
      source: stageWallpaper
      visible: stageWallpaper.status === Image.Ready
      blurEnabled: true
      blurMax: 64
      blur: root.reveal
      saturation: 0.25
      autoPaddingEnabled: false
    }

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.45)
      opacity: root.reveal
      MouseArea { anchors.fill: parent; onClicked: root.cancel() }
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          root.cancel()
          event.accepted = true
        } else if (event.key === Qt.Key_Left) {
          root.select(-1)
          event.accepted = true
        } else if (event.key === Qt.Key_Right) {
          root.select(1)
          event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.commit()
          event.accepted = true
        }
      }
      Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Alt) {
          root.commit()
          event.accepted = true
        }
      }

      Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - Style.space(64), root.overviewColumns * overviewGrid.cellWidth)
        spacing: Style.space(20)

        Text {
          width: parent.width
          text: "WINDOWS"
          color: Color.foreground
          opacity: 0.75
          horizontalAlignment: Text.AlignHCenter
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        GridView {
          id: overviewGrid
          width: parent.width
          height: Math.min(overlay.height - Style.space(170),
            Math.ceil(root.windows.length / root.overviewColumns) * cellHeight)
          cellWidth: root.cardWidth + Style.space(20)
          cellHeight: root.cardHeight + Style.space(30)
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          model: root.windows
          currentIndex: root.selectedIndex

          delegate: Item {
            id: overviewCard
            required property int index
            required property var modelData
            readonly property bool selected: index === root.selectedIndex
            readonly property bool hovered: index === root.hoveredIndex
            readonly property bool currentWindow: modelData.focusHistoryId === 0
            width: overviewGrid.cellWidth
            height: overviewGrid.cellHeight
            scale: (overviewCard.selected ? 1.035 : overviewCard.hovered ? 1.02 : 1)
              * (0.88 + 0.12 * root.reveal)
            opacity: root.reveal

            Rectangle {
              anchors.fill: card
              anchors.margins: -4
              color: overviewCard.selected
                ? Qt.rgba(root.selectionColor.r, root.selectionColor.g, root.selectionColor.b, 0.18)
                : overviewCard.hovered ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : "transparent"
              border.width: overviewCard.selected ? 3 : overviewCard.hovered ? 2 : 0
              border.color: overviewCard.selected ? root.selectionColor : Color.foreground
              opacity: overviewCard.selected || overviewCard.hovered ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: 120 } }
            }

            Rectangle {
              id: card
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.verticalCenter: parent.verticalCenter
              width: root.cardWidth
              height: root.cardHeight
              color: Color.menu.background
              border.width: overviewCard.selected ? 2 : 1
              border.color: overviewCard.selected ? root.selectionColor
                : overviewCard.hovered ? Color.foreground : Color.menu.border
              clip: true

              Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: titleRow.height + Style.space(20)
                color: Qt.rgba(root.selectionColor.r, root.selectionColor.g, root.selectionColor.b,
                  overviewCard.selected ? 0.22 : overviewCard.hovered ? 0.10 : 0)
              }

              Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: titleRow.top
                anchors.margins: root.cardPadding
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
                clip: true
                Text {
                  anchors.centerIn: parent
                  width: parent.width - Style.space(20)
                  text: overviewCard.modelData.appClass
                  color: Color.menu.text
                  opacity: overviewPreview.hasContent ? 0 : 0.65
                  horizontalAlignment: Text.AlignHCenter
                  elide: Text.ElideRight
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                }
                ScreencopyView {
                  id: overviewPreview
                  anchors.fill: parent
                  captureSource: root.opened && overviewCard.modelData.wayland ? overviewCard.modelData.wayland : null
                  paintCursor: false
                  live: false
                  constraintSize: Qt.size(Math.max(1, width), Math.max(1, height))
                  opacity: hasContent ? 1 : 0
                }

                Rectangle {
                  anchors.top: parent.top
                  anchors.right: parent.right
                  anchors.margins: Style.space(8)
                  width: selectionLabel.implicitWidth + Style.space(14)
                  height: selectionLabel.implicitHeight + Style.space(8)
                  color: root.selectionColor
                  visible: overviewCard.selected
                  Text {
                    id: selectionLabel
                    anchors.centerIn: parent
                    text: "SELECTED"
                    color: Color.background
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }

                Rectangle {
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.margins: Style.space(8)
                  width: currentLabel.implicitWidth + Style.space(14)
                  height: currentLabel.implicitHeight + Style.space(8)
                  color: Color.menu.background
                  border.width: 1
                  border.color: Color.menu.border
                  visible: overviewCard.currentWindow && !overviewCard.selected
                  Text {
                    id: currentLabel
                    anchors.centerIn: parent
                    text: "CURRENT"
                    color: Color.menu.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }

              Column {
                id: titleRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Style.space(10)
                spacing: Style.space(2)
                Text {
                  width: parent.width
                  text: overviewCard.modelData.appClass
                  color: Color.menu.text
                  elide: Text.ElideRight
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.bold: overviewCard.selected || overviewCard.hovered
                }
                Text {
                  width: parent.width
                  text: overviewCard.modelData.title
                  color: Color.menu.text
                  opacity: 0.72
                  elide: Text.ElideRight
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.hoveredIndex = overviewCard.index
                onExited: if (root.hoveredIndex === overviewCard.index) root.hoveredIndex = -1
                onClicked: {
                  root.selectedIndex = overviewCard.index
                  root.commit()
                }
              }
            }
          }
        }

        Text {
          width: parent.width
          text: "← →  SELECT    ENTER / CLICK  SWITCH    ESC  CLOSE"
          color: Color.foreground
          opacity: 0.7
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

    }
  }
}

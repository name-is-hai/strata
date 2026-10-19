import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Placement.js" as Placement

Item {
  id: controls
  required property var service
  property bool opened: false
  property var targetScreen: null
  property string imagePath: ""
  property var draft: Placement.normalize({})
  property string errorText: ""
  readonly property string monitorName: targetScreen ? targetScreen.name : ""
  readonly property bool canAdjust: !!service.currentBackground && !service.isVideo(service.currentBackground)

  function adjust(screen) {
    targetScreen = screen || targetScreen
    imagePath = service.currentBackground
    draft = service.savedPlacement(monitorName, imagePath)
    service.requestNativeSize(imagePath)
    errorText = ""
    opened = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }
  function close() { opened = false; errorText = "" }
  function change(key, value) {
    var next = Object.assign({}, draft)
    next[key] = value
    draft = Placement.normalize(next)
  }
  function save() {
    if (saveProcess.running) return
    saveProcess.entry = Object.assign({monitor: monitorName, path: imagePath}, draft)
    saveProcess.errors = ""
    saveProcess.command = ["strata-background-placement", "save", JSON.stringify(saveProcess.entry)]
    saveProcess.running = true
  }
  onTargetScreenChanged: {
    if (opened && !targetScreen) close()
    else if (opened) controlsRemap.remap()
  }
  Connections {
    target: service
    function onCurrentBackgroundChanged() { if (controls.opened) controls.close() }
  }
  Connections {
    target: Quickshell
    function onScreensChanged() {
      if (controls.opened && Quickshell.screens.indexOf(controls.targetScreen) === -1) controls.close()
    }
  }
  Process {
    id: saveProcess
    property var entry: ({})
    property string errors: ""
    stderr: StdioCollector { onStreamFinished: saveProcess.errors = text.trim() }
    onExited: function(code) {
      if (code !== 0) { controls.errorText = errors || "Could not save background position"; return }
      controls.service.commitPlacement(entry)
      controls.close()
    }
  }

  PanelWindow {
    id: controlsWindow
    screen: controls.targetScreen
    visible: controls.opened && !!controls.targetScreen && !controlsRemap.remapping
    ScreenMoveRemap { id: controlsRemap; window: controlsWindow }
    onBackingWindowVisibleChanged: if (backingWindowVisible && controls.opened) Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    anchors { top: true; bottom: true; left: true; right: true }
    color: Color.background
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "strata-background-controls"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: controls.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    WallpaperFrame {
      anchors.fill: parent
      path: controls.imagePath
      placement: controls.draft
      nativeSize: controls.service.nativeSizes[path] || null
      decodeSize: Qt.size(controlsWindow.width * (controlsWindow.screen ? controlsWindow.screen.devicePixelRatio : 1),
                          controlsWindow.height * (controlsWindow.screen ? controlsWindow.screen.devicePixelRatio : 1))
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
      preventStealing: true
      property point origin
      property var startPlacement
      onPressed: function(mouse) { origin = Qt.point(mouse.x, mouse.y); startPlacement = controls.draft }
      onPositionChanged: function(mouse) {
        if (!pressed) return
        var size = controls.service.nativeSizes[controls.imagePath] || {}
        controls.draft = Placement.dragged(startPlacement, mouse.x - origin.x, mouse.y - origin.y,
          width, height, size.width || width, size.height || height)
      }
      onWheel: function(wheel) {
        controls.change("zoom", Math.max(1, Math.min(3, controls.draft.zoom + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
        wheel.accepted = true
      }
    }
    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: controls.close()
      Keys.onReturnPressed: if (!saveProcess.running) controls.save()
      BorderSurface {
        id: toolbar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(24)
        width: Math.max(1, Math.min(Style.space(780), parent.width - Style.space(32)))
        height: Math.min(Math.ceil(content.implicitHeight + actions.implicitHeight + Style.space(34)
          + borderTop + borderBottom), parent.height - Style.space(32))
        color: Color.popups.background
        borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
        radius: Style.cornerRadius
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onWheel: function(wheel) { wheel.accepted = true } }
        Flickable {
          id: scrollArea
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.bottom: actions.top
          anchors.leftMargin: toolbar.borderLeft + Style.space(12)
          anchors.rightMargin: toolbar.borderRight + Style.space(12)
          anchors.topMargin: toolbar.borderTop + Style.space(12)
          anchors.bottomMargin: Style.space(10)
          contentWidth: width
          contentHeight: content.implicitHeight
          clip: true
          Controls.ScrollBar.vertical: PanelScrollBar {}
          Column {
            id: content
            width: scrollArea.width
            spacing: Style.space(10)
            Text {
              text: "Adjust background · " + controls.monitorName + " · Drag to move · Scroll to zoom"
              width: parent.width
              wrapMode: Text.WordWrap
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
            Flow {
              width: parent.width
              spacing: Style.space(6)
              Repeater {
                model: Quickshell.screens
                delegate: Button {
                  required property var modelData
                  text: modelData.name
                  selected: modelData === controls.targetScreen
                  onClicked: controls.adjust(modelData)
                }
              }
              Repeater {
                model: ["Fill", "Fit", "Stretch", "Center"]
                delegate: Button {
                  required property string modelData
                  text: modelData
                  bordered: true
                  selected: controls.draft.mode === modelData.toLowerCase()
                  onClicked: controls.change("mode", modelData.toLowerCase())
                }
              }
            }
            PanelSlider {
              width: parent.width
              wheelEnabled: false
              minimum: 1; maximum: 3; step: 0.05
              value: controls.draft.zoom
              onMoved: function(value) { controls.change("zoom", Math.round(value * 100) / 100) }
            }
            Text {
              visible: !!controls.errorText
              width: parent.width
              text: controls.errorText
              wrapMode: Text.WordWrap
              color: Color.urgent
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
        }
        Flow {
          id: actions
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.leftMargin: toolbar.borderLeft + Style.space(12)
          anchors.rightMargin: toolbar.borderRight + Style.space(12)
          anchors.bottomMargin: toolbar.borderBottom + Style.space(12)
          spacing: Style.space(8)
          Button { text: "Reset"; bordered: true; onClicked: controls.draft = Placement.normalize({}) }
          Button { text: "Cancel · Esc"; bordered: true; onClicked: controls.close() }
          Button { text: saveProcess.running ? "Saving…" : "Save · Enter"; bordered: true; enabled: !saveProcess.running; onClicked: controls.save() }
        }
      }
    }
  }
}

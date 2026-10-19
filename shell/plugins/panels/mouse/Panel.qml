import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "strata.mouse"
  ipcTarget: "strata.mouse"
  property var values: ({ touchpad_sensitivity: 0, touchpad_accel_profile: "", sensitivity: 0, scroll_factor: 1, natural_scroll: false, left_handed: false, accel_profile: "" })
  property string settingsBaseline: ""
  property bool previewed: false
  property bool discarding: false
  property bool loaded: false
  property bool saved: false
  property string errorText: ""
  readonly property var mouseService: bar && bar.shell ? bar.shell.serviceFor("strata.mouse") : null
  readonly property var devices: mouseService ? mouseService.devices : []

  readonly property var externalMice: devices.filter(function(device) { return device.external === true })
  readonly property bool hasTouchpad: devices.some(function(device) { return device.touchpad === true })
  visible: hasMouse || hasTouchpad
  readonly property bool hasMouse: externalMice.length > 0
  readonly property string deviceName: hasMouse ? externalMice[0].name : "Touchpad"
  readonly property string deviceIcon: hasMouse ? "󰍽" : "󰟸"

  function refresh() { if (!readProcess.running && !writeProcess.running && !discarding) readProcess.running = true }
  function discard() {
    applyTimer.stop()
    loaded = false
    discarding = true
    if (writeProcess.running) return
    if (previewed && settingsBaseline !== "") {
      writeProcess.mode = "restore"
      writeProcess.snapshot = settingsBaseline
      writeProcess.errors = ""
      writeProcess.command = ["strata-mouse-settings", "apply", settingsBaseline]
      writeProcess.running = true
    } else {
      discarding = false
      if (settingsBaseline !== "") values = JSON.parse(settingsBaseline)
      if (opened) refresh()
    }
  }
  function change(key, value) {
    var next = Object.assign({}, values)
    next[key] = value
    values = next
    saved = false
    errorText = ""
    applyTimer.restart()
  }
  function apply(save) {
    if (!opened || !loaded || discarding) return
    if (writeProcess.running) { applyTimer.restart(); return }
    previewed = true
    writeProcess.mode = save ? "save" : "apply"
    writeProcess.snapshot = JSON.stringify(values)
    writeProcess.errors = ""
    writeProcess.command = ["strata-mouse-settings", save ? "save" : "apply", writeProcess.snapshot]
    writeProcess.running = true
  }
  onOpenedChanged: {
    if (opened) {
      viewport.contentY = 0
      saved = false
      if (discarding) discard(); else refresh()
      if (mouseService) mouseService.refresh()
    } else discard()
  }
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.deviceIcon
    foreground: root.mouseService && root.mouseService.lowBattery ? Color.urgent : root.barForeground
    tooltipText: root.hasMouse ? "Mouse settings" : "Touchpad settings"
    active: root.opened
    onPressed: root.toggle()
  }

  Process {
    id: readProcess
    command: ["strata-mouse-settings", "get"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { if (root.opened && !root.discarding) { root.values = JSON.parse(text); root.settingsBaseline = JSON.stringify(root.values); root.previewed = false; root.loaded = true; root.errorText = "" } }
        catch (error) { root.errorText = "Could not read mouse settings" }
      }
    }
    onExited: function(code) { if (code !== 0) root.errorText = "Could not read mouse settings" }
  }
  Process {
    id: writeProcess
    property string mode: "apply"
    property string snapshot: ""
    property string errors: ""
    stderr: StdioCollector { onStreamFinished: writeProcess.errors = String(text).trim() }
    onExited: function(code) {
      if (code !== 0) root.errorText = errors || "Could not apply mouse settings"
      else {
        root.errorText = ""
        if (mode === "save") {
          root.settingsBaseline = snapshot
          root.previewed = false
          root.saved = snapshot === JSON.stringify(root.values)
        } else if (mode === "restore") {
          root.values = JSON.parse(snapshot)
          root.previewed = false
          root.discarding = false
        }
      }
      if (mode === "restore" && code !== 0) return
      if (root.discarding) Qt.callLater(root.discard)
      else if (root.opened && !root.loaded) Qt.callLater(root.refresh)
    }
  }
  Timer { id: applyTimer; interval: 120; onTriggered: root.apply(false) }

  component AccelerationControl: Column {
    id: acceleration
    required property string settingKey
    required property string profile
    width: parent.width
    spacing: Style.space(6)
    PanelSectionHeader { text: "ACCELERATION" }
    Row {
      width: parent.width
      spacing: Style.space(6)
      Repeater {
        model: ["Adaptive", "Flat"]
        delegate: Button {
          required property string modelData
          width: (parent.width - parent.spacing) / 2
          text: modelData
          bordered: true
          focusable: true
          enabled: root.loaded
          selected: acceleration.profile === modelData.toLowerCase() || (acceleration.profile === "" && modelData === "Adaptive")
          onClicked: root.change(acceleration.settingKey, modelData.toLowerCase())
        }
      }
    }
  }

  PopupCard {
    id: panel
    panelHeader: hero
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    margin: Style.space(16)
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(650))

    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      onCloseRequested: root.close()
      PanelHero {
        id: hero
        parent: panel.headerContainer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Math.max(Style.space(42), implicitHeight)
        title: root.hasMouse ? "Mouse" : "Touchpad"
        meta: root.deviceName
        detail: root.saved ? "Saved" : root.hasMouse && root.externalMice[0].percentage !== null ? Math.round(root.externalMice[0].percentage) + "%" : ""
        iconComponent: Component {
          Text { text: root.deviceIcon; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.display }
        }
      }
      Flickable {
        id: viewport
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: Style.space(16)
        clip: true
        contentHeight: content.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: PanelScrollBar {
          width: Style.space(6)
          parent: viewport.parent
          anchors.top: viewport.top
          anchors.bottom: viewport.bottom
          anchors.right: parent.right
          anchors.rightMargin: Style.space(4) - panel.padding
        }
        Column {
          id: content
          width: parent.width
          spacing: Style.spacing.panelGap
          Column {
            width: parent.width
            spacing: Style.spacing.panelGap
            visible: root.hasMouse
            PanelSectionHeader { text: "MOUSE" }
            PanelSectionHeader { text: "POINTER SPEED · " + Math.round((root.values.sensitivity + 1) * 50) + "%" + (root.values.sensitivity === 0 ? " · DEFAULT" : "") }
            PanelSlider {
              wheelEnabled: false
              width: parent.width
              bar: root.bar
              enabled: root.loaded
              minimum: 0; maximum: 20; step: 1
              integer: true
              tickCount: 21
              value: (root.values.sensitivity + 1) * 10
              onReleased: function(value) { root.change("sensitivity", Math.round((value / 10 - 1) * 100) / 100) }
            }
            PanelSectionHeader { text: "SCROLL SPEED · " + Number(root.values.scroll_factor).toFixed(1) + "×" }
            PanelSlider {
              wheelEnabled: false
              width: parent.width
              bar: root.bar
              enabled: root.loaded
              minimum: 0.1; maximum: 3; step: 0.1
              value: root.values.scroll_factor
              onReleased: function(value) { root.change("scroll_factor", Math.round(value * 10) / 10) }
            }
            AccelerationControl {
              settingKey: "accel_profile"
              profile: root.values.accel_profile
            }
            Toggle {
              width: parent.width
              enabled: root.loaded
              label: "Natural scroll"
              checked: root.values.natural_scroll
              onClicked: root.change("natural_scroll", !checked)
            }
            Toggle {
              width: parent.width
              enabled: root.loaded
              label: "Left-handed buttons"
              checked: root.values.left_handed
              onClicked: root.change("left_handed", !checked)
            }
          }
          Column {
            width: parent.width
            spacing: Style.spacing.panelGap
            visible: root.hasTouchpad
            PanelSeparator { visible: root.hasMouse }
            PanelSectionHeader { text: "TOUCHPAD" }
            PanelSectionHeader { text: "POINTER SPEED · " + Math.round((root.values.touchpad_sensitivity + 1) * 50) + "%" + (root.values.touchpad_sensitivity === 0 ? " · DEFAULT" : "") }
            PanelSlider {
              wheelEnabled: false
              width: parent.width
              bar: root.bar
              enabled: root.loaded
              minimum: 0; maximum: 20; step: 1
              integer: true
              tickCount: 21
              value: (root.values.touchpad_sensitivity + 1) * 10
              onReleased: function(value) { root.change("touchpad_sensitivity", Math.round((value / 10 - 1) * 100) / 100) }
            }
            PanelSectionHeader { text: "SCROLL SPEED · " + Number(root.values.touchpad_scroll_factor || 0.5).toFixed(1) + "×" }
            PanelSlider {
              wheelEnabled: false
              width: parent.width
              bar: root.bar
              enabled: root.loaded
              minimum: 0.1; maximum: 3; step: 0.1
              value: root.values.touchpad_scroll_factor || 0.5
              onReleased: function(value) { root.change("touchpad_scroll_factor", Math.round(value * 10) / 10) }
            }
            AccelerationControl {
              settingKey: "touchpad_accel_profile"
              profile: root.values.touchpad_accel_profile || ""
            }
            Repeater {
              model: [
                { key: "touchpad_natural_scroll", label: "Natural scroll" },
                { key: "touchpad_disable_while_typing", label: "Pause while typing" },
                { key: "touchpad_tap_to_click", label: "Tap to click" },
                { key: "touchpad_tap_and_drag", label: "Tap and drag" }
              ]
              delegate: Toggle {
                required property var modelData
                width: parent.width
                enabled: root.loaded
                label: modelData.label
                checked: root.values[modelData.key] === true
                onClicked: root.change(modelData.key, !checked)
              }
            }
          }
          Text {
            width: parent.width
            text: root.errorText || "Changes preview immediately. Save to keep them; closing discards unsaved changes."
            color: root.errorText ? Color.urgent : Color.foreground
            opacity: root.errorText ? 1 : 0.65
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
          Button {
            width: parent.width
            text: writeProcess.running ? "Applying…" : root.saved ? "Saved" : "Save"
            iconText: "\uf0c7"
            bordered: true
            enabled: root.loaded && !writeProcess.running
            onClicked: { applyTimer.stop(); root.apply(true) }
          }
        }
      }
    }
  }
}

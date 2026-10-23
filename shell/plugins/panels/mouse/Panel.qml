import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "strata.mouse"
  ipcTarget: "strata.mouse"
  property var service: null
  property var values: ({ touchpad_sensitivity: 0, touchpad_accel_profile: "", sensitivity: 0, scroll_factor: 1, natural_scroll: false, left_handed: false, accel_profile: "" })
  property string settingsBaseline: ""
  property bool previewed: false
  property bool discarding: false
  property bool loaded: false
  property bool saved: false
  readonly property bool settingsChanged: loaded && settingsBaseline !== "" && JSON.stringify(values) !== settingsBaseline
  property string errorText: ""
  property var configurationDevices: []
  property string configurationMessage: ""
  readonly property var mouseService: service
  readonly property var devices: mouseService ? mouseService.devices : []

  readonly property var externalMice: devices.filter(function(device) { return device.external === true })
  readonly property bool hasTouchpad: devices.some(function(device) { return device.touchpad === true })
  readonly property bool hasMouse: externalMice.length > 0
  readonly property string deviceName: hasMouse ? externalMice[0].name : hasTouchpad ? "Touchpad" : "No pointer device detected"
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
      configurationMessage = ""
      if (!configurationQuery.running) configurationQuery.running = true
    } else discard()
  }

  Process {
    id: configurationQuery
    command: ["strata-mouse-setup", "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var next = JSON.parse(text)
          if (!Array.isArray(next)) return
          if (JSON.stringify(next) !== JSON.stringify(root.configurationDevices)) root.configurationDevices = next
        }
        catch (error) { root.configurationDevices = [] }
      }
    }
  }
  Process {
    id: configurationSetup
    property string operation: "enable"
    property string message: ""
    stdout: StdioCollector { onStreamFinished: configurationSetup.message = String(text).trim() }
    stderr: StdioCollector { onStreamFinished: if (String(text).trim()) configurationSetup.message = String(text).trim() }
    onExited: function(code) {
      root.configurationMessage = code === 0
        ? operation === "remove"
          ? "Saved access removed. Unplug/reconnect the mouse to revoke its current access."
          : "Enabled. Reconnect the mouse in your browser; future USB reconnects are automatic."
        : message || "Could not change configuration access."
      if (!configurationQuery.running) configurationQuery.running = true
    }
  }
  Timer {
    interval: 3000
    running: root.opened
    repeat: true
    onTriggered: if (!configurationQuery.running && !configurationSetup.running) configurationQuery.running = true
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

  KeyboardPanel {
    id: panel
    panelHeader: hero
    standalone: true
    anchorItem: null
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keys
    margin: Style.space(16)
    contentWidth: panel.fittedContentWidth(Style.space(root.hasMouse && root.hasTouchpad ? 720 : 460))
    // Include the focus inset and round up so fractional text metrics cannot
    // create a one-pixel scroll range on a screen with room for the content.
    contentHeight: Math.min(Math.ceil(viewport.contentHeight + panel.verticalContentInset),
      panel.availableCardHeight > 0 ? panel.availableCardHeight : Infinity)

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
        title: root.hasMouse && root.hasTouchpad ? "Mouse & Touchpad" : root.hasTouchpad ? "Touchpad" : "Mouse"
        meta: root.deviceName
        detail: root.settingsChanged ? "Unsaved changes" : root.saved ? "Saved" : root.hasMouse && root.externalMice[0].percentage !== null ? Math.round(root.externalMice[0].percentage) + "%" : ""
        trailingControl: Component {
          Button {
            objectName: "mouseSettingsSave"
            text: writeProcess.running && writeProcess.mode === "save" ? "Saving…" : root.saved ? "Saved" : "Save"
            iconText: "\uf0c7"
            tooltipText: "Changes preview immediately. Save keeps them; closing discards unsaved changes."
            bordered: true
            focusable: true
            selected: root.settingsChanged
            enabled: root.settingsChanged && !writeProcess.running && !root.discarding
            onClicked: { applyTimer.stop(); root.apply(true) }
          }
        }
        iconComponent: Component {
          Text { text: root.deviceIcon; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.display }
        }
      }
      Flickable {
        id: viewport
        objectName: "mouseSettingsViewport"
        readonly property int controlInset: Math.max(1, Style.space(2))
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true
        contentWidth: width
        contentHeight: content.implicitHeight + controlInset * 2
        flickableDirection: Flickable.VerticalFlick
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
          x: viewport.controlInset
          y: viewport.controlInset
          width: Math.max(0, viewport.width - viewport.controlInset * 2)
          spacing: Style.spacing.panelGap
          Grid {
            id: settingsGrid
            objectName: "mouseSettingsGrid"
            width: parent.width
            columns: root.hasMouse && root.hasTouchpad && width >= Style.space(600) ? 2 : 1
            columnSpacing: Style.space(24)
            rowSpacing: Style.spacing.panelGap
            Column {
              width: (parent.width - (parent.columns - 1) * parent.columnSpacing) / parent.columns
              spacing: Style.space(10)
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
                implicitHeight: Math.max(Style.space(36), Style.font.subtitle + Style.space(16))
                width: parent.width
                enabled: root.loaded
                label: "Natural scroll"
                checked: root.values.natural_scroll
                onClicked: root.change("natural_scroll", !checked)
              }
              Toggle {
                implicitHeight: Math.max(Style.space(36), Style.font.subtitle + Style.space(16))
                width: parent.width
                enabled: root.loaded
                label: "Left-handed buttons"
                checked: root.values.left_handed
                onClicked: root.change("left_handed", !checked)
              }
            }
            Column {
              width: (parent.width - (parent.columns - 1) * parent.columnSpacing) / parent.columns
              spacing: Style.space(10)
              visible: root.hasTouchpad
              PanelSeparator { visible: root.hasMouse && settingsGrid.columns === 1 }
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
                  implicitHeight: Math.max(Style.space(36), Style.font.subtitle + Style.space(16))
                  required property var modelData
                  width: parent.width
                  enabled: root.loaded
                  label: modelData.label
                  checked: root.values[modelData.key] === true
                  onClicked: root.change(modelData.key, !checked)
                }
              }
            }
          }
          Column {
            width: parent.width
            spacing: Style.spacing.controlGap
            objectName: "mouseConfigurationSection"
            visible: root.configurationDevices.length > 0
            PanelSeparator {}
            PanelSectionHeader { text: "DEVICE CONFIGURATION" }
            Text {
              width: parent.width
              text: "Approve each mouse once for browser tools. Reconnects are automatic."
              color: Color.foreground
              opacity: 0.65
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
            Flow {
              id: deviceCards
              width: parent.width
              spacing: Style.spacing.controlGap
              readonly property int columns: width >= Style.space(600) ? 2 : 1
              readonly property real cardHeight: {
                var tallest = 0
                for (var i = 0; i < children.length; i++) {
                  if (children[i].naturalHeight !== undefined) tallest = Math.max(tallest, children[i].naturalHeight)
                }
                return tallest
              }
              Repeater {
                model: root.configurationDevices
                Rectangle {
                  id: deviceCard
                  required property var modelData
                  readonly property bool configured: modelData.configured === true
                  readonly property bool connected: modelData.connected !== false
                  readonly property int inset: Style.space(10)
                  width: deviceCards.columns === 2 ? (deviceCards.width - deviceCards.spacing) / 2 : deviceCards.width
                  readonly property real naturalHeight: Math.max(deviceLabels.implicitHeight, deviceAction.implicitHeight) + inset * 2
                  implicitHeight: naturalHeight
                  height: deviceCards.cardHeight
                  radius: Style.cornerRadius
                  color: Qt.alpha(Color.foreground, 0.025)
                  border.width: 1
                  border.color: Qt.alpha(Color.foreground, 0.12)
                  FontMetrics { id: deviceNameMetrics; font: deviceLabel.font }

                  Column {
                    id: deviceLabels
                    anchors.left: parent.left
                    anchors.right: deviceAction.left
                    anchors.leftMargin: deviceCard.inset
                    anchors.rightMargin: Style.space(10)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(4)
                    Text {
                      id: deviceLabel
                      width: parent.width
                      height: deviceNameMetrics.height * 2
                      text: deviceCard.modelData.name
                      textFormat: Text.PlainText
                      color: Color.foreground
                      font.family: Style.font.family
                      font.pixelSize: Style.font.bodySmall
                      wrapMode: Text.Wrap
                      maximumLineCount: 2
                      elide: Text.ElideRight
                      HoverHandler { id: deviceNameHover }
                      PanelToolTip {
                        visible: deviceNameHover.hovered
                        text: deviceCard.modelData.name
                      }
                    }
                    Text {
                      width: parent.width
                      text: (deviceCard.configured ? "Allowed" : "Not enabled")
                        + (deviceCard.connected ? "" : " · Unplugged") + " · " + deviceCard.modelData.id
                      color: deviceCard.configured ? Color.accent : Qt.alpha(Color.foreground, 0.6)
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      wrapMode: Text.Wrap
                    }
                  }
                  Button {
                    id: deviceAction
                    objectName: "mouseConfigurationAction"
                    anchors.right: parent.right
                    anchors.rightMargin: deviceCard.inset
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(Style.space(72), implicitWidth)
                    text: deviceCard.configured ? "Remove" : "Enable"
                    fontSize: Style.font.caption
                    tooltipText: deviceCard.configured
                      ? "Delete this approval. Unplug/reconnect to revoke current access."
                      : "Allow browser configuration for " + deviceCard.modelData.id
                    bordered: true
                    focusable: true
                    enabled: !configurationSetup.running && (deviceCard.configured || deviceCard.connected)
                    onClicked: {
                      root.configurationMessage = ""
                      configurationSetup.message = ""
                      configurationSetup.operation = deviceCard.configured ? "remove" : "enable"
                      configurationSetup.command = ["strata-mouse-setup", configurationSetup.operation, deviceCard.modelData.id]
                      configurationSetup.running = true
                    }
                  }
                }
              }
            }
            Text {
              width: parent.width
              text: "Only approve your mouse; keyboards may expose mouse interfaces too."
              color: Qt.alpha(Color.foreground, 0.5)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
            Text {
              width: parent.width
              visible: root.configurationMessage !== ""
              text: root.configurationMessage
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }
          Text {
            width: parent.width
            visible: root.errorText !== ""
            text: root.errorText
            color: Color.urgent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }
}

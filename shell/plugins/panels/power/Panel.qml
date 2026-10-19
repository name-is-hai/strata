import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "strata.power"
  ipcTarget: "strata.power"
  // manageIpc: false so this panel can own the single IpcHandler the target
  // permits — needed for the togglePercentage method below.
  manageIpc: false
  property var batteryInfo: ({})
  property var systemInfo: ({})
  property var profiles: []
  property string activeProfile: ""
  property int profileIndex: 0
  property bool cursorActive: false
  // null means older UPower versions cannot report this property; retain the
  // existing battery-state detection in that case.
  property var chargeThresholdEnabled: null
  readonly property string effectiveThreshold: chargeThresholdEnabled === false
    ? "" : (batteryInfo.threshold || "")
  readonly property bool showPercentage: setting("showPercentage", false) === true
  // With the percentage shown the button paints a text block wider than an
  // icon, so the open-panel mark takes the painted width instead of the
  // icon-sized fraction of the slot the fallback assumes.
  readonly property real openPanelIndicatorWidth: showPercentage && !button.vertical ? button.glyphPaintedWidth : 0
  readonly property bool batteryPresent: {
    var device = UPower.displayDevice
    return !!(device && device.isPresent)
  }

  function upowerStates() {
    return {
      Charging: UPowerDeviceState.Charging,
      Discharging: UPowerDeviceState.Discharging,
      FullyCharged: UPowerDeviceState.FullyCharged,
      PendingCharge: UPowerDeviceState.PendingCharge
    }
  }

  function selectProfileByDelta(delta) {
    profileIndex = Model.selectProfileIndex(profileIndex, delta, profiles)
  }

  function activateSelectedProfile() {
    if (profileIndex < 0 || profileIndex >= profiles.length) return
    setProfile(profiles[profileIndex])
  }

  function batteryIcon() {
    var device = UPower.displayDevice
    return Model.batteryIcon(device, root.discharging, upowerStates(), root.effectiveThreshold)
  }

  function modeLabel() {
    var device = UPower.displayDevice
    return Model.modeLabel(device, root.discharging, upowerStates(), root.effectiveThreshold)
  }

  function profileIcon(name) {
    return Model.profileIcon(name)
  }

  readonly property bool fullyCharged: {
    var device = UPower.displayDevice
    return device && device.isPresent && device.state === UPowerDeviceState.FullyCharged && !root.chargeThresholdActive
  }
  readonly property bool discharging: {
    var device = UPower.displayDevice
    return !!(device && device.isPresent && UPower.onBattery)
  }
  readonly property bool chargeThresholdActive: {
    var device = UPower.displayDevice
    return Model.chargeThresholdActive(device, root.discharging, upowerStates(), root.effectiveThreshold)
  }
  readonly property bool batteryFull: fullyCharged || (!root.discharging && batteryFraction >= 1)
  readonly property bool batteryFlowIdle: batteryFull || chargeThresholdActive ||
    (UPower.displayDevice && UPower.displayDevice.state === UPowerDeviceState.PendingCharge)

  // 0..1 charge level, used by the visual progress bar.
  readonly property real batteryFraction: {
    var d = UPower.displayDevice
    return Model.batteryFraction(d)
  }

  readonly property bool charging: {
    var d = UPower.displayDevice
    return d && d.isPresent && !UPower.onBattery && d.state === UPowerDeviceState.Charging && !root.batteryFlowIdle
  }

  readonly property color batteryFillColor: {
    return root.bar ? root.bar.foreground : Color.foreground
  }

  readonly property string heroStatusText: {
    if (chargeThresholdActive || fullyCharged || batteryFlowIdle) return modeLabel()
    var rate = batteryInfo.rate || ""
    return modeLabel() + (rate ? " · " + rate : "")
  }

  function refresh() {
    if (!batteryPresent) return

    if (!batteryProc.running) batteryProc.running = true
    if (!profilesProc.running) profilesProc.running = true
    if (!systemProc.running) systemProc.running = true
  }

  function updateKeyValue(raw, targetName) {
    var next = Model.parseKeyValue(raw)
    // Keep last known good data if a refresh briefly returns nothing — happens
    // around AC plug/unplug events. Avoids the section collapsing mid-transition.
    if (Object.keys(next).length === 0) return
    if (targetName === "battery") batteryInfo = next
    else systemInfo = next
  }

  function updateProfiles(raw) {
    var parsed = Model.parseProfiles(raw, profileIndex)
    // Same guard as battery: preserve the last known profile list across
    // transient empty payloads so the buttons don't blink out.
    if (parsed.profiles.length === 0) return
    profiles = parsed.profiles
    activeProfile = parsed.activeProfile
    profileIndex = parsed.profileIndex
    if (opened && !cursorActive) {
      var idx = profiles.indexOf(activeProfile)
      if (idx >= 0) profileIndex = idx
    }
  }

  function setProfile(profile) {
    if (!profile || actionProc.running) return
    actionProc.command = ["strata-powerprofiles-set", root.discharging ? "battery" : "ac", profile]
    actionProc.running = true
  }

  function togglePercentage() {
    root.settings = Object.assign({}, root.settings, { showPercentage: !root.showPercentage })
    if (root.bar && root.bar.shell) root.bar.shell.updateEntryInline(root.moduleName, root.settings)
  }

  ShellIpc {
    target: "strata.power"

    function open() { root.open() }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
    function togglePercentage() { root.togglePercentage() }
  }

  onOpenedChanged: {
    if (opened) {
      if (!batteryPresent) {
        close()
        return
      }

      refresh()
      var idx = profiles.indexOf(activeProfile)
      profileIndex = idx >= 0 ? idx : 0
      cursorActive = false
    }
  }

  onBatteryPresentChanged: if (!batteryPresent) close()

  visible: batteryPresent
  implicitWidth: batteryPresent ? button.implicitWidth : 0
  implicitHeight: batteryPresent ? button.implicitHeight : 0

  Process {
    id: batteryProc
    command: ["strata-battery-status", "--shell"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateKeyValue(text, "battery") }
  }

  Process {
    id: profilesProc
    command: ["strata-powerprofiles-list", "--active-state"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateProfiles(text) }
  }

  Process {
    id: systemProc
    command: ["strata-system-stats"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateKeyValue(text, "system") }
  }

  Process {
    id: actionProc
    onExited: root.refresh()
  }

  Timer { interval: 5000; running: root.opened; repeat: true; onTriggered: root.refresh() }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: root.batteryPresent
    // Percentage mode should fit its content, not reserve two entire icon
    // slots. The old reservation left a conspicuous gap after the audio icon.
    fixedWidth: vertical ? -1 : (root.showPercentage
      ? Math.ceil(button.contentWidth + Style.bar.contentPx(8))
      : Style.bar.iconSlot)
    fixedHeight: vertical ? Style.bar.iconSlot : -1
    // Keep the panel underline centered under the actual percentage + glyph,
    // instead of the larger fixed slot.
    readonly property real glyphPaintedWidth: percentageText.visible
      ? percentageText.implicitWidth + Style.bar.contentPx(4) + batteryGlyph.tightWidth
      : batteryGlyph.tightWidth
    readonly property real contentWidth: percentageText.visible
      ? percentageText.implicitWidth + Style.bar.contentPx(4) + batteryGlyph.width
      : batteryGlyph.width
    tooltipText: ""
    onPressed: function(b) {
      if (!root.batteryPresent) return
      if (b === Qt.RightButton) root.togglePercentage()
      else root.toggle()
    }

    Text {
      id: percentageText
      visible: root.showPercentage && !button.vertical
      anchors.left: parent.left
      anchors.leftMargin: Style.bar.contentPx(4)
      anchors.right: batteryGlyph.left
      anchors.rightMargin: Style.bar.contentPx(4)
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: height / 2 - baselineOffset - button.figureInk.y - button.figureInk.height / 2
      text: Math.round(root.batteryFraction * 100) + "%"
      color: button.foreground
      font.family: button.fontFamily
      font.pixelSize: button.fontSize
      horizontalAlignment: Text.AlignRight
      verticalAlignment: Text.AlignVCenter
      renderType: Text.NativeRendering
    }

    OpticalGlyph {
      id: batteryGlyph
      width: Style.bar.iconCanvas
      height: width
      x: percentageText.visible ? parent.width - width - Style.bar.contentPx(4) : (parent.width - width) / 2
      y: (parent.height - height) / 2
      text: root.batteryIcon()
      fontFamily: button.fontFamily
      fontSize: Style.bar.iconFont
      targetPaintedExtent: Math.max(1, Math.min(Style.bar.iconSize, parent.width, parent.height))
      color: button.foreground
    }
  }

  KeyboardPanel {
    id: panel
    panelHeader: panelTitleHeader
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened && root.batteryPresent
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(500))
    contentHeight: panel.fittedContentHeight(column.implicitHeight + Style.space(8), Style.space(820))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dx !== 0) root.selectProfileByDelta(dx)
        else if (dy !== 0) root.selectProfileByDelta(dy)
      }
      onActivateRequested: if (root.cursorActive) root.activateSelectedProfile()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: scroller
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight + Style.space(8)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        ScrollBar.vertical: PanelScrollBar {
          parent: scroller.parent
          anchors.top: scroller.top
          anchors.bottom: scroller.bottom
          anchors.right: parent.right
          anchors.rightMargin: Style.space(4) - panel.padding
          width: thickness
          policy: ScrollBar.AsNeeded
        }

        Column {
          id: column
          // Font outlines can extend past a Text item's advance box. Keep
          // a small inset inside the clipping viewport for those pixels.
          x: Style.space(4)
          y: Style.space(4)
          width: Math.max(0, scroller.width - Style.space(8))
          spacing: Style.space(14)

        // ---------- Hero: battery icon · title/status · percentage ----------
        PanelHeaderSurface {
          id: panelTitleHeader
          parent: panel.headerContainer
          width: parent.width
          headerForeground: root.bar.foreground
          implicitHeight: Style.space(58)


          Column {
            id: heroLabels
            anchors.left: parent.left
            anchors.leftMargin: Style.space(16)
            anchors.right: heroPercent.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Power & battery"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              id: heroStatus
              textFormat: Text.PlainText
              text: root.heroStatusText
              color: Util.alpha(root.bar.foreground, 0.6)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption

              elide: Text.ElideRight
              width: parent.width
            }
          }

          Text {
            id: heroPercent
            textFormat: Text.PlainText
            text: root.batteryInfo.percentage || "—"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            anchors.right: parent.right
            anchors.rightMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: Style.duration(200) } }
          }
        }

        Item {
          width: parent.width
          implicitHeight: Style.space(6)
          Rectangle {
            id: barTrack
            anchors.fill: parent
            radius: height / 2
            color: Util.alpha(root.bar.foreground, 0.12)
          }
          Rectangle {
            anchors.left: parent.left
            width: parent.width * root.batteryFraction
            height: parent.height
            radius: height / 2
            color: root.batteryFillColor
            Behavior on width { NumberAnimation { duration: Style.duration(220) } }
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(18)
          InfoPair {
            width: (parent.width - parent.spacing) / 2
            label: root.discharging ? "Time left" : (root.charging ? "To full" : "Power source")
            value: root.discharging || root.charging ? (root.batteryInfo.time || "—") : "Plugged in"
          }
          InfoPair {
            width: (parent.width - parent.spacing) / 2
            label: "Power draw"
            value: root.batteryInfo.rate || "—"
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: root.batteryInfo.percentage !== undefined
          Row {
            width: parent.width
            spacing: Style.space(18)
            InfoPair {
              width: (parent.width - parent.spacing) / 2
              label: "Health"
              value: root.batteryInfo.health || "—"
            }
            InfoPair {
              width: (parent.width - parent.spacing) / 2
              label: "Cycles"
              value: root.batteryInfo.cycles || "—"
            }
          }
          Row {
            width: parent.width
            spacing: Style.space(18)
            InfoPair {
              width: (parent.width - parent.spacing) / 2
              label: "Capacity"
              value: root.batteryInfo.capacity || root.batteryInfo.size || "—"
            }
            InfoPair {
              width: (parent.width - parent.spacing) / 2
              label: "Temp"
              value: root.batteryInfo.battery_temp
                ? root.batteryInfo.battery_temp + (root.batteryInfo.cpu_temp ? " · cpu " + root.batteryInfo.cpu_temp : "")
                : (root.batteryInfo.cpu_temp ? "cpu " + root.batteryInfo.cpu_temp : "—")
            }
          }
        }

        BatteryExtras {
          id: batteryExtras
          width: parent.width
          bar: root.bar
          batteryInfo: root.batteryInfo
          panelOpen: root.opened
          onThresholdInfoChanged: root.chargeThresholdEnabled = thresholdInfo.supported === "true"
            ? thresholdInfo.enabled === "true" : null
        }
        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: batteryExtras.impactApps.length > 0
          PanelSeparator { foreground: root.bar.foreground }
          PanelSectionHeader {
            width: parent.width
            text: "Recent app activity"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }
          Repeater {
            model: batteryExtras.impactApps
            InfoPair {
              required property var modelData
              label: modelData.name
              value: modelData.impact + " · " + modelData.cpu.toFixed(0) + "% CPU"
            }
          }
          Text {
            width: parent.width
            text: "Estimated from CPU activity, not measured app wattage."
            wrapMode: Text.WordWrap
            color: Util.alpha(root.bar.foreground, 0.55)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        Column {
          width: parent.width
          spacing: Style.space(10)
          PanelSectionHeader {
            text: "POWER PROFILE"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }
          Row {
            id: profileRow
            width: parent.width
            spacing: Style.space(6)
            readonly property real cellWidth: root.profiles.length > 0
              ? (width - spacing * (root.profiles.length - 1)) / root.profiles.length : 0
            Repeater {
              model: root.profiles
              Button {
                required property var modelData
                required property int index
                width: profileRow.cellWidth
                iconText: root.profileIcon(String(modelData))
                iconSize: Style.font.title
                text: String(modelData).charAt(0).toUpperCase() + String(modelData).slice(1)
                fontSize: Style.font.bodySmall
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                bordered: true
                active: root.activeProfile === modelData
                hasCursor: root.cursorActive && root.profileIndex === index
                enabled: !actionProc.running
                onClicked: root.setProfile(modelData)
                onHovered: function(hovered) {
                  if (hovered) {
                    root.cursorActive = true
                    root.profileIndex = index
                  }
                }
              }
            }
          }
        }

        IdleSettings {
          id: idleSettings
          width: parent.width
          bar: root.bar
          profile: root.activeProfile || "balanced"
          panelOpen: root.opened
        }

        SettingsCard {
          title: "Battery protection"
          description: "Reduce time spent at a full charge"
          visible: batteryExtras.thresholdInfo.supported === "true" && !!root.batteryInfo.threshold
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          Toggle {
            width: parent.width
            label: "Charge limit"
            description: "Hold at " + root.batteryInfo.threshold
            checked: batteryExtras.thresholdInfo.enabled === "true"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            enabled: !batteryExtras.thresholdBusy
            onClicked: batteryExtras.toggleThreshold()
          }
          Text {
            width: parent.width
            visible: batteryExtras.thresholdError !== ""
            text: batteryExtras.thresholdError
            wrapMode: Text.WordWrap
            color: Color.urgent
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
          }
        }



        }
      }
    }
  }

  component InfoPair: Item {
    id: pair
    property string label: ""
    property string value: ""
    readonly property real gap: Style.space(8)
    readonly property bool stacked: labelText.implicitWidth + valueText.implicitWidth + gap > width

    width: parent.width
    implicitHeight: stacked
      ? labelText.implicitHeight + Style.space(2) + valueText.implicitHeight
      : Math.max(labelText.implicitHeight, valueText.implicitHeight)
    height: implicitHeight

    InfoLabel {
      id: labelText
      text: pair.label
      anchors.left: parent.left
      anchors.top: parent.top
    }
    InfoValue {
      id: valueText
      text: pair.value
      width: pair.stacked ? parent.width : Math.max(0, parent.width - labelText.implicitWidth - pair.gap)
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.topMargin: pair.stacked ? labelText.implicitHeight + Style.space(2) : 0
      horizontalAlignment: Text.AlignRight
      elide: Text.ElideRight
    }
  }

  component InfoLabel: Text {
    textFormat: Text.PlainText
    color: root.bar.foreground
    opacity: 0.6
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  component InfoValue: Text {
    textFormat: Text.PlainText
    color: root.bar.foreground
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}

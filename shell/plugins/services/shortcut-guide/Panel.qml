import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
  id: root
  property var shell: null
  property var service: null
  property bool closingFromHost: false
  property string errorText: ""
  readonly property var settings: service ? service.localSettings : ({})

  function option(key, fallback) {
    return settings && settings[key] !== undefined ? settings[key] : fallback
  }
  function save(key, value) {
    if (writer.running) return
    errorText = ""
    writer.command = ["strata-shortcut-guide", "set", key, String(value)]
    writer.running = true
  }
  function open(payloadJson) {
    window.visible = true
    Qt.callLater(function() { focusScope.forceActiveFocus() })
  }
  function close() {
    closingFromHost = true
    window.visible = false
    closingFromHost = false
  }
  function requestClose() {
    if (shell && typeof shell.hide === "function") shell.hide("strata.shortcut-guide")
    else close()
  }

  Process {
    id: writer
    onExited: function(code) { if (code !== 0) root.errorText = "Could not save this setting" }
  }

  component Caption: Text {
    width: parent.width
    textFormat: Text.PlainText
    color: Color.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.bold: true
  }

  FloatingWindow {
    id: window
    title: "Strata Shortcut Guide"
    visible: false
    color: Color.background
    implicitWidth: 540
    implicitHeight: 640
    minimumSize: Qt.size(420, 420)
    onVisibleChanged: {
      if (!visible && !root.closingFromHost && root.shell) root.shell.hide("strata.shortcut-guide")
    }

    PanelHero {
      id: settingsHeader
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      title: "Shortcut Guide"
      meta: "Hold a modifier to discover shortcuts"
    }

    FocusScope {
      id: focusScope
      anchors.fill: parent
      anchors.margins: Style.space(24)
      anchors.topMargin: settingsHeader.height + Style.space(24)
      focus: true
      Keys.onEscapePressed: root.requestClose()

      Flickable {
        id: scroll
        Controls.ScrollBar.vertical: PanelScrollBar {}
        anchors.fill: parent
        contentWidth: width
        readonly property int contentInset: Style.space(6)
        contentHeight: content.implicitHeight + contentInset * 2
        clip: true
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: content
          x: scroll.contentInset
          y: scroll.contentInset
          width: Math.max(1, scroll.width - scroll.contentInset * 2 - Style.space(12))
          spacing: Style.space(14)
          enabled: !writer.running

          Toggle {
            width: parent.width
            label: "Shortcut Guide"
            description: "Enable the guide and shortcut reminders"
            checked: root.option("enabled", true)
            onClicked: root.save("enabled", !checked)
          }
          Caption { text: "APPEARANCE DELAY" }
          Flow {
            width: parent.width
            spacing: Style.space(6)
            Repeater {
              model: [0, 250, 500, 750, 1000]
              delegate: Button {
                required property int modelData
                text: modelData === 0 ? "Instant" : modelData + " ms"
                bordered: true
                selected: root.option("guideDelayMs", 500) === modelData
                onClicked: root.save("guideDelayMs", modelData)
              }
            }
          }
          Caption { text: "START THE GUIDE WITH" }
          Grid {
            id: roots
            width: parent.width
            columns: 2
            spacing: Style.space(8)
            Repeater {
              model: [
                { label: "Super", key: "guideSuperEnabled", defaultValue: true },
                { label: "Shift", key: "guideShiftEnabled", defaultValue: false },
                { label: "Ctrl", key: "guideCtrlEnabled", defaultValue: false },
                { label: "Alt", key: "guideAltEnabled", defaultValue: false }
              ]
              delegate: Toggle {
                required property var modelData
                width: (roots.width - roots.spacing) / 2
                label: modelData.label
                checked: root.option(modelData.key, modelData.defaultValue)
                onClicked: root.save(modelData.key, !checked)
              }
            }
          }
          Text {
            width: parent.width
            text: "Add other modifiers to narrow the guide. Release the starting key to close it."
            color: Color.foreground
            opacity: 0.65
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
          Toggle {
            width: parent.width
            label: "Show over fullscreen apps"
            checked: root.option("showInFullscreen", false)
            onClicked: root.save("showInFullscreen", !checked)
          }
          Caption { text: "DISTANCE FROM TOP EDGE" }
          Flow {
            width: parent.width
            spacing: Style.space(6)
            Repeater {
              model: [0, 24, 32, 48, 64]
              delegate: Button {
                required property int modelData
                text: modelData + " px"
                bordered: true
                selected: root.option("guideTopOffset", 0) === modelData
                onClicked: root.save("guideTopOffset", modelData)
              }
            }
          }
          Toggle {
            width: parent.width
            label: "Shortcut reminders"
            description: "Show the shortcut after choosing a menu action"
            checked: root.option("promoterEnabled", true)
            onClicked: root.save("promoterEnabled", !checked)
          }
          Caption { text: "REMINDER POSITION" }
          Flow {
            width: parent.width
            spacing: Style.space(6)
            Repeater {
              model: [ {label: "Center", value: "center"}, {label: "Bottom", value: "bottom-center"}, {label: "Bottom right", value: "bottom-right"} ]
              delegate: Button {
                required property var modelData
                text: modelData.label
                bordered: true
                selected: root.option("promoterPosition", "center") === modelData.value
                onClicked: root.save("promoterPosition", modelData.value)
              }
            }
          }
          Text {
            visible: root.errorText !== ""
            width: parent.width
            text: root.errorText
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }
}

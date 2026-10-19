import QtQuick
import qs.Commons
import qs.Ui

Column {
  id: root
  property string title: ""
  property string detail: ""
  property int seconds: 0
  property var presets: [0, 300, 600, 900, 1800]
  property bool busy: false
  property bool available: true
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property int customHours: 0
  property int customMinutes: 5
  property bool customVisible: false
  signal chosen(int seconds)

  width: parent ? parent.width : implicitWidth
  spacing: Style.space(10)

  function labelFor(value) {
    if (value === 0) return "Never"
    if (value < 3600) return (value / 60) + " min"
    if (value % 3600 === 0) return (value / 3600) + (value === 3600 ? " hour" : " hours")
    return Math.floor(value / 3600) + "h " + Math.floor(value % 3600 / 60) + "m"
  }

  function timerOptions() {
    var values = presets.slice()
    if (values.indexOf(seconds) < 0) values.push(seconds)
    values.sort(function(a, b) { return a - b })
    var options = values.map(function(value) { return {value: String(value), label: root.labelFor(value)} })
    options.push({value: "custom", label: "Custom…"})
    return options
  }

  onSecondsChanged: {
    customHours = Math.floor(seconds / 3600)
    customMinutes = Math.floor((seconds % 3600) / 60)
    customVisible = false
  }
  onVisibleChanged: if (!visible) timeout.close()
  onBusyChanged: if (busy) timeout.close()

  Item {
    width: parent.width
    implicitHeight: Math.max(labels.implicitHeight, timeout.implicitHeight)
    Column {
      id: labels
      width: parent.width - timeout.width - Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(4)
      Text {
        width: parent.width
        text: root.title
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }
      Text {
        width: parent.width
        visible: root.detail !== ""
        text: root.detail
        color: Util.alpha(root.foreground, 0.55)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }
    Dropdown {
      id: timeout
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(Style.space(140), parent.width * 0.43)
      showLabel: false
      foreground: root.foreground
      fontFamily: root.fontFamily
      enabled: root.available && !root.busy
      updateValueOnSelection: false
      value: root.customVisible ? "custom" : String(root.seconds)
      options: root.timerOptions()
      onChanged: function(value) {
        if (value === "custom") {
          root.customHours = Math.floor(root.seconds / 3600)
          root.customMinutes = Math.floor(root.seconds % 3600 / 60)
          root.customVisible = true
        } else {
          root.customVisible = false
          root.chosen(Number(value))
        }
      }
    }
  }

  Row {
    width: parent.width
    spacing: Style.space(8)
    visible: root.customVisible
    enabled: root.available && !root.busy
    NumberField {
      label: "Hours"
      from: 0; to: 168
      value: root.customHours
      fieldWidth: Math.min(Style.space(86), (parent.width - apply.implicitWidth - parent.spacing * 2) / 2)
      foreground: root.foreground
      fontFamily: root.fontFamily
      onModified: function(value) { root.customHours = value }
    }
    NumberField {
      label: "Minutes"
      from: 0; to: 59
      value: root.customMinutes
      fieldWidth: Math.min(Style.space(86), (parent.width - apply.implicitWidth - parent.spacing * 2) / 2)
      foreground: root.foreground
      fontFamily: root.fontFamily
      onModified: function(value) { root.customMinutes = value }
    }
    Button {
      id: apply
      anchors.bottom: parent.bottom
      text: "Apply"
      bordered: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: {
        root.customVisible = false
        root.chosen((root.customHours * 60 + root.customMinutes) * 60)
      }
    }
  }
}

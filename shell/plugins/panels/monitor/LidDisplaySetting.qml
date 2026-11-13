import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Column {
  id: root
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property bool disableOnClose: true
  property string errorText: ""
  spacing: Style.space(4)
  readonly property string settingsPath: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/strata/display-settings.json"

  function readSettings() {
    try {
      var settings = JSON.parse(settingsFile.text() || "{}")
      disableOnClose = settings.disableOnLidClose !== false
    } catch (error) { errorText = "Could not read display preferences" }
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    printErrors: false
    onLoaded: root.readSettings()
    onLoadFailed: root.disableOnClose = true
    onFileChanged: reload()
  }

  Process {
    id: saveSetting
    onExited: function(code) {
      settingsFile.reload()
      if (code !== 0) root.errorText = "Could not apply the lid display setting"
    }
  }

  Item {
    width: parent.width
    implicitHeight: Math.max(label.implicitHeight, toggle.implicitHeight)
    Text {
      id: label
      anchors.left: parent.left
      anchors.right: toggle.left
      anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      text: "Disable laptop display when lid closes"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
    }
    ToggleSwitch {
      id: toggle
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      checked: root.disableOnClose
      busy: saveSetting.running
      foreground: root.foreground
      onToggled: {
        root.errorText = ""
        saveSetting.command = ["strata-display-settings", "set", "disableOnLidClose", root.disableOnClose ? "false" : "true"]
        saveSetting.running = true
      }
    }
  }
  Text {
    width: parent.width
    text: root.errorText || "With another display connected. Opening the lid restores the layout. Saved automatically."
    color: root.errorText ? Color.urgent : Util.alpha(root.foreground, 0.6)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }
}

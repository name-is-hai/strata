pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Ui
import qs.Commons
import "../Preferences.js" as Preferences
import "../Translations.js" as Translations

Column {
  id: root
  objectName: scope + "-" + field.key + "Field"
  required property string scope
  required property var field
  required property var settings
  required property string language
  readonly property var current: Preferences.value(scope, settings, field.key)
  readonly property var displayOptions: {
    var options = Quickshell.screens.map(function(screen) {
      var name = String(screen.name)
      return { value: name, label: /^(eDP|LVDS)-/.test(name) ? name + " · Built-in display" : name }
    })
    var saved = String(root.current || "")
    if (saved && !options.some(function(option) { return option.value === saved }))
      options.push({value: saved, label: saved + " (disconnected)"})
    if (!saved) options.unshift({value: "", label: "Choose a display"})
    return options
  }
  signal save(var value)
  signal clearError()
  signal pasteFailed(string message)
  function tr(label) { return Translations.text(label, language) }
  Loader {
    width: parent.width
    active: root.field.type === "enum"
    visible: active
    sourceComponent: Component {
      SettingsDropdown {
        objectName: root.scope + "-" + root.field.key
        width: parent.width
        label: root.tr(root.field.label)
        fontFamily: Style.font.family
        value: String(root.current)
        options: root.field.options.map(function(value) { return {value:value,label:root.tr(Preferences.optionLabel(value,root.field.key))} })
        onChanged: function(value) { root.save(value) }
      }
    }
  }
  Loader {
    width: parent.width
    active: root.field.type === "boolean"
    visible: active
    sourceComponent: Component {
      Toggle {
        objectName: root.scope + "-" + root.field.key
        width: parent.width
        implicitHeight: Math.max(Style.space(42), toggleLabel.implicitHeight + Style.space(16))
        color: "transparent"
        borderSpec: activeFocus ? Border.flat(Color.accent, 1) : Border.none()
        radius: Style.cornerRadius * 2
        foreground: Color.popups.text
        fontFamily: Style.font.family
        titleSize: Style.space(13)
        label: ""
        checked: root.current === true
        Accessible.role: Accessible.CheckBox
        Accessible.name: root.tr(root.field.label)
        Accessible.checkable: true
        Accessible.checked: checked
        Accessible.onToggleAction: if (enabled) root.save(!checked)
        onClicked: root.save(!checked)
        Text {
          id: toggleLabel
          anchors.left: parent.left
          anchors.leftMargin: Style.spacing.rowPaddingX
          anchors.verticalCenter: parent.verticalCenter
          width: Math.max(0, parent.width - Style.space(80))
          text: root.tr(root.field.label)
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.space(13)
        }
      }
    }
  }
  Loader {
    width: parent.width
    active: root.field.type === "integer"
    visible: active
    sourceComponent: Component {
      RowLayout {
        width: parent.width
        spacing: Style.space(12)
        Text {
          Layout.fillWidth: true
          text: root.tr(root.field.label)
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.space(13)
        }
        SafeTextField {
          id: input
          objectName: root.scope + "-" + root.field.key
          Layout.preferredWidth: Style.space(68)
          implicitHeight: Style.space(34)
          text: String(root.current)
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.space(12)
          padding: Style.space(7)
          Accessible.name: root.tr(root.field.label)
          background: Rectangle {
            radius: Style.cornerRadius * 2
            color: Qt.alpha(Color.popups.text, 0.055)
            border.width: input.inputActiveFocus ? 1 : 0
            border.color: Color.accent
          }
          translate: root.tr
          onPasteErrorChanged: if (pasteError !== "") root.pasteFailed(pasteError)
          onTextEdited: root.clearError()
          onEditingFinished: {
            if (!root.visible || !root.enabled) return
            var next = text.trim() === "" ? NaN : Number(text)
            if (next !== root.current) root.save(next)
          }
          // Cancel the editor without saving an unfinished value on Escape.
          onKeyPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              event.accepted = true
              text = Qt.binding(function() { return String(root.current) })
              root.forceActiveFocus()
            }
          }
          HoverHandler { id: numberHover }
          PanelToolTip {
            visible: numberHover.hovered || input.inputActiveFocus
            text: root.field.min + "–" + root.field.max
            fontFamily: Style.font.family
          }
        }
      }
    }
  }
  Loader {
    width: parent.width
    active: root.field.type === "string" && root.field.key !== "displayName"
    visible: active
    sourceComponent: Component {
      Column {
        width: parent.width
        spacing: Style.space(6)
        Text { text: root.field.label; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
        SafeTextField {
          width: parent.width
          implicitHeight: Style.space(38)
          text: String(root.current || "")
          padding: Style.space(8)
          color: Color.popups.text
          font.family: Style.font.family
          background: Rectangle { color: Qt.alpha(Color.popups.text, 0.055); border.width: 1; border.color: Color.popups.border }
          onEditingFinished: if (root.visible && root.enabled && text !== root.current) root.save(text)
        }
      }
    }
  }
  Loader {
    width: parent.width
    active: root.field.key === "displayName"
    visible: active
    sourceComponent: Component {
      SettingsDropdown {
        objectName: "notificationDisplayPicker"
        width: parent.width
        label: "Display"
        fontFamily: Style.font.family
        value: String(root.current || "")
        options: root.displayOptions
        onChanged: function(value) { root.save(value) }
      }
    }
  }
  Loader {
    width: parent.width
    active: root.field.type === "multiselect"
    visible: active
    sourceComponent: Component {
      Column {
        width: parent.width
        spacing: Style.space(6)
        Text { text: root.field.label; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
        Repeater {
          model: root.field.options
          delegate: Toggle {
            required property var modelData
            width: parent.width
            label: modelData.label || String(modelData)
            readonly property string optionValue: modelData.value || String(modelData)
            checked: Array.isArray(root.current) && root.current.indexOf(optionValue) >= 0
            onClicked: {
              var next = Array.isArray(root.current) ? root.current.slice() : []
              var index = next.indexOf(optionValue)
              if (index >= 0) next.splice(index, 1); else next.push(optionValue)
              root.save(next)
            }
          }
        }
      }
    }
  }

}

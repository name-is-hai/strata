import QtQuick
import QtQuick.Controls
import qs.Commons

Popup {
  id: menu
  property var strip: null
  property int desktopId: 0
  readonly property var service: strip ? strip.service : null
  readonly property var choices: service ? service.transferChoices(desktopId) : []
  parent: strip && strip.overview ? strip.overview.stage : null
  width: Math.min(Style.space(320), parent ? parent.width - 24 : Style.space(320))
  padding: Style.space(8)
  focus: true
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

  background: Glass { style: "solid"; radius: Style.space(2) }

  onOpened: rename.forceActiveFocus(Qt.PopupFocusReason)

  onClosed: {
    if (strip && strip.overview && strip.renamingDesktop === 0) strip.overview.focusKeys()
  }
  Connections {
    target: menu.service
    function onShownChanged() { if (menu.service && !menu.service.shown) menu.close() }
  }

  contentItem: Column {
    spacing: Style.space(6)
    Button {
      id: rename
      objectName: "rename-workspace"
      width: parent.width
      height: Style.space(36)
      text: "Rename"
      background: Glass { style: "solid"; selected: rename.hovered; selectedColor: Color.accent }
      contentItem: Text {
        text: rename.text
        color: Color.foreground
        font.family: menu.service ? menu.service.uiFont : Style.font.family
        font.pixelSize: Style.font.body
        verticalAlignment: Text.AlignVCenter
      }
      onClicked: {
        menu.close()
        Qt.callLater(function() { if (menu.strip) menu.strip.beginRename(menu.desktopId) })
      }
    }
    Text {
      width: parent.width
      text: "Move workspace to…"
      color: Color.foreground
      opacity: 0.65
      font.family: menu.service ? menu.service.uiFont : Style.font.family
      font.pixelSize: Style.font.body
      topPadding: Style.space(8)
      bottomPadding: Style.space(3)
    }
    Repeater {
      model: menu.choices
      delegate: Button {
        id: destination
        required property var modelData
        objectName: "move-" + modelData.name
        width: parent.width
        height: Style.space(40)
        enabled: modelData.number > 0
        text: modelData.name + (modelData.number > 0 ? " · workspace " + modelData.number : " · full")
        background: Glass { style: "solid"; selected: destination.hovered; selectedColor: Color.accent }
        contentItem: Text {
          text: destination.text
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: Color.foreground
          opacity: destination.enabled ? 1 : 0.4
          font.family: menu.service ? menu.service.uiFont : Style.font.family
          font.pixelSize: Style.font.body
          verticalAlignment: Text.AlignVCenter
        }
        onClicked: {
          menu.close()
          menu.service.transferDesktop(menu.desktopId, modelData.name)
        }
      }
    }
    Text {
      visible: menu.choices.length === 0
      width: parent.width
      text: "Connect another display to move this workspace."
      wrapMode: Text.WordWrap
      color: Color.foreground
      opacity: 0.6
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
  }
}

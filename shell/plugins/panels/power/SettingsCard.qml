import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  id: root
  default property alias content: body.data
  property string title: ""
  property string description: ""
  property color foreground: Color.popups.text
  property string fontFamily: Style.font.family
  property bool collapsible: false
  property bool expanded: true
  signal toggleRequested()

  width: parent ? parent.width : implicitWidth
  padding: Style.space(14)
  color: Util.alpha(foreground, 0.035)
  borderSpec: Border.flat(Util.alpha(foreground, 0.13), 1)
  radius: Style.cornerRadius
  implicitHeight: padding * 2 + heading.height + (body.visible && body.implicitHeight > 0
    ? (heading.height > 0 ? Style.space(14) : 0) + body.implicitHeight : 0)

  Item {
    id: heading
    x: root.padding; y: root.padding
    width: parent.width - root.padding * 2
    height: root.title ? Math.max(labels.implicitHeight, Style.space(22)) : 0
    visible: root.title !== ""
    activeFocusOnTab: root.collapsible
    Keys.onReturnPressed: if (root.collapsible) root.toggleRequested()
    Keys.onSpacePressed: if (root.collapsible) root.toggleRequested()

    Column {
      id: labels
      width: parent.width - (root.collapsible ? Style.space(26) : 0)
      spacing: Style.space(4)
      Text {
        width: parent.width
        text: root.title
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        wrapMode: Text.WordWrap
      }
      Text {
        width: parent.width
        visible: root.description !== ""
        text: root.description
        color: Util.alpha(root.foreground, 0.6)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }
    Text {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      visible: root.collapsible
      text: root.expanded ? "󰅀" : "󰅂"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
    MouseArea {
      anchors.fill: parent
      enabled: root.collapsible
      cursorShape: Qt.PointingHandCursor
      onClicked: { heading.forceActiveFocus(); root.toggleRequested() }
    }
  }

  Column {
    id: body
    x: root.padding
    y: root.padding + heading.height + (heading.height > 0 ? Style.space(14) : 0)
    width: parent.width - root.padding * 2
    spacing: Style.space(12)
    visible: !root.collapsible || root.expanded
  }
}

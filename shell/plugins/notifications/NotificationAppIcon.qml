import QtQuick
import qs.Commons

// The same app icon or initial is used by both the popup and the panel.
Item {
  id: root
  property string iconSource: ""
  property string fallbackLetter: "?"
  property color tint: "white"
  property real textScale: 1

  Image {
    id: applicationImage
    anchors.fill: parent
    source: root.iconSource
    fillMode: Image.PreserveAspectFit
    sourceSize.width: width * Screen.devicePixelRatio
    sourceSize.height: height * Screen.devicePixelRatio
    asynchronous: true
    visible: status === Image.Ready
  }

  Rectangle {
    anchors.fill: parent
    visible: applicationImage.status !== Image.Ready
    radius: Math.min(width, height) * 0.1
    color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.05)
    border.width: 1
    border.color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.32)

    Text {
      anchors.centerIn: parent
      text: String(root.fallbackLetter || "?").substring(0, 1).toUpperCase()
      textFormat: Text.PlainText
      color: root.tint
      font.family: Style.font.family
      font.pixelSize: Math.round(Math.max(Style.font.title, root.height * 0.42) * root.textScale)
      font.bold: true
    }
  }
}

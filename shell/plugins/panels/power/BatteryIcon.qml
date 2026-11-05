import QtQuick
import qs.Commons
import qs.Ui

// Capsule layout inspired by jacker-nz/omarchy-power-inside (MIT).
// Draw at the bar's actual size instead of relying on a battery font glyph.
Item {
  id: icon
  property real fraction: 0
  property bool charging: false
  property bool discharging: false
  property color foreground: Color.foreground
  property color urgent: Color.urgent
  property string fontFamily: Style.font.family
  readonly property real level: Math.max(0, Math.min(1, fraction))
  readonly property bool low: discharging && level <= 0.2
  readonly property real unit: height / 16.8
  readonly property real statusWidth: charging ? 12 * unit : 0
  readonly property color fillColor: low ? urgent : charging ? "#a3be8c" : foreground
  readonly property color rimColor: low ? urgent : Util.alpha(foreground, 0.55)
  readonly property color trackColor: Util.alpha(foreground, 0.6)
  // A contrasting track keeps the same digit color readable across the fill.
  readonly property color digitColor: (0.2126 * foreground.r + 0.7152 * foreground.g + 0.0722 * foreground.b) > 0.5 ? "#101315" : "#ffffff"
  implicitHeight: 16.8
  implicitWidth: statusWidth + 34.2 * unit

  OpticalGlyph {
    visible: icon.charging
    width: icon.statusWidth - 2 * icon.unit
    height: icon.height
    text: "󱐋"
    fontFamily: icon.fontFamily
    fontSize: 14 * icon.unit
    targetPaintedExtent: 12 * icon.unit
    color: icon.fillColor
  }

  Rectangle {
    id: body
    x: icon.statusWidth
    width: 31 * icon.unit
    height: icon.height
    radius: 4.5 * icon.unit
    color: "transparent"
    border.width: Math.max(1, 1.2 * icon.unit)
    border.color: icon.rimColor

    Rectangle {
      id: track
      anchors.fill: parent
      anchors.margins: 2.4 * icon.unit
      radius: 2 * icon.unit
      color: icon.trackColor

      Rectangle {
        width: track.width * icon.level
        height: track.height
        radius: track.radius
        color: icon.fillColor
      }
      BatteryDigits {
        width: track.width; height: track.height
        color: icon.digitColor
      }
    }
  }

  Rectangle {
    x: body.x + body.width + icon.unit
    anchors.verticalCenter: parent.verticalCenter
    width: 2.2 * icon.unit
    height: 7.2 * icon.unit
    radius: icon.unit
    color: icon.rimColor
  }

  component BatteryDigits: Item {
    TextMetrics {
      id: reference
      font.family: icon.fontFamily
      font.weight: Font.Bold
      font.pixelSize: 240 * icon.unit
      text: "0"
    }
    Text {
      id: digits
      text: String(Math.round(icon.level * 100))
      textFormat: Text.PlainText
      font.family: icon.fontFamily
      font.pixelSize: 12 * icon.unit
      font.weight: Font.Bold
      renderType: Text.QtRendering
      color: parent.color
      anchors.horizontalCenter: parent.horizontalCenter
      y: (parent.height - reference.tightBoundingRect.height / 20) / 2
         - baselineOffset - reference.tightBoundingRect.y / 20
    }
    property color color: icon.digitColor
  }
}

import QtQuick
import qs.Commons

// Shared header treatment, matching the notification center. Children keep
// their own controls; the surface never handles pointer or keyboard input.
Item {
  id: root
  property color headerForeground: Color.popups.text
  implicitHeight: Style.space(58)

  Canvas {
    anchors.fill: parent
    z: -1
    property color surface: Color.popups.background
    property color accent: Color.accent
    property real cornerRadius: Math.max(0, Style.cornerRadius - 1)
    onSurfaceChanged: requestPaint()
    onAccentChanged: requestPaint()
    onCornerRadiusChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var r = Math.min(cornerRadius, width / 2, height)
      ctx.beginPath()
      ctx.moveTo(r, 0)
      ctx.lineTo(width - r, 0)
      ctx.arcTo(width, 0, width, r, r)
      ctx.lineTo(width, height)
      ctx.lineTo(0, height)
      ctx.lineTo(0, r)
      ctx.arcTo(0, 0, r, 0, r)
      ctx.closePath()
      var wash = ctx.createLinearGradient(0, 0, width, height)
      wash.addColorStop(0, Qt.tint(surface, Util.alpha(accent, 0.12)))
      wash.addColorStop(1, Qt.tint(surface, Util.alpha(accent, 0.035)))
      ctx.fillStyle = wash
      ctx.fill()
    }
  }
  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 1
    color: Util.alpha(root.headerForeground, 0.08)
  }
}

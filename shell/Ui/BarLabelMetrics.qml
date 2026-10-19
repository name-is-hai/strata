import QtQuick
import qs.Commons

// Share native text sizing between bar buttons and standalone text labels.
QtObject {
  id: root
  property string fontFamily: Style.font.family
  property real targetHeight: Style.bar.labelSize
  readonly property rect sourceInk: FontInk.rect(fontFamily, 100, "0123456789", sourceMetrics.tightBoundingRect)
  readonly property int pixelSize: Math.max(1, Math.floor(100 * targetHeight / Math.max(1, sourceInk.height)))
  property real fontSize: pixelSize
  readonly property rect figureInk: FontInk.rect(fontFamily, Math.max(1, Math.round(fontSize)),
    "0123456789", renderedMetrics.tightBoundingRect)

  property TextMetrics sourceMetrics: TextMetrics {
    font.family: root.fontFamily
    font.pixelSize: 100
    renderType: Text.NativeRendering
    text: "0123456789"
  }
  property TextMetrics renderedMetrics: TextMetrics {
    font.family: root.fontFamily
    font.pixelSize: Math.max(1, Math.round(root.fontSize))
    renderType: Text.NativeRendering
    text: "0123456789"
  }
}

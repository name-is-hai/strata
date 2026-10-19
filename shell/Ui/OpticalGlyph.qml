import QtQuick
import qs.Commons

Item {
  id: root

  property string text: ""
  property string fontFamily: Style.font.family
  property real fontSize: Style.font.body
  property color color: Color.foreground
  property bool debugBounds: false
  // When set, fit the actual painted bounds into a common square extent.
  // This keeps icons optically equal without changing their bar slot.
  property real targetPaintedExtent: 0
  property real targetPaintedHeight: 0
  property real maximumPaintedWidth: 0
  // Some font glyphs include blank padding in their reported tight metrics.
  property bool fitPaintedInk: false
  readonly property rect sourceInk: fitPaintedInk || targetPaintedExtent > 0
    ? FontInk.rect(fontFamily, Math.max(1, Math.round(fontSize)), text, sourceMetrics.tightBoundingRect)
    : sourceMetrics.tightBoundingRect

  readonly property real sourcePaintedExtent: Math.max(1, Math.max(sourceInk.width, sourceInk.height))
  readonly property real paintedScale: targetPaintedExtent > 0
    ? targetPaintedExtent / sourcePaintedExtent
    : targetPaintedHeight > 0
    ? Math.min(targetPaintedHeight / Math.max(1, sourceInk.height),
      maximumPaintedWidth > 0 ? maximumPaintedWidth / Math.max(1, sourceInk.width) : Infinity)
    : 1
  readonly property int renderedFontSize: Math.max(1, targetPaintedExtent > 0
    ? Math.floor(fontSize * paintedScale + 0.00001) : Math.round(fontSize * paintedScale))
  readonly property rect actualInk: FontInk.rect(fontFamily, renderedFontSize, text, glyphMetrics.tightBoundingRect)
  readonly property rect paintedRect: Qt.rect(
    glyph.x + root.actualInk.x,
    glyph.y + glyph.baselineOffset + root.actualInk.y,
    root.actualInk.width, root.actualInk.height)
  readonly property real tightWidth: Math.max(1, root.actualInk.width)
  readonly property real horizontalCorrection: glyph.implicitWidth / 2 - (root.actualInk.x + tightWidth / 2)
  readonly property real paintedCenterX: glyph.x + root.actualInk.x + tightWidth / 2
  readonly property real baselineY: glyph.y + glyph.baselineOffset

  // Measure at the requested font size first, then scale to the requested
  // visual extent. Keeping this separate avoids a circular metric binding.
  TextMetrics {
    id: sourceMetrics
    renderType: Text.NativeRendering
    font.family: root.fontFamily
    font.pixelSize: Math.max(1, Math.round(root.fontSize))
    text: root.text
  }

  TextMetrics {
    id: glyphMetrics
    renderType: Text.NativeRendering
    font.family: root.fontFamily
    font.pixelSize: root.renderedFontSize
    text: root.text
  }

  Text {
    id: glyph
    textFormat: Text.PlainText
    // Fit bar glyphs around their actual ink, keeping both centers exact.
    // Callers without a target extent retain ordinary font line-box placement.
    // Fractional coordinates keep odd-width slots centered on their underline.
    x: (parent.width - implicitWidth) / 2 + root.horizontalCorrection
    y: root.targetPaintedExtent > 0 || root.targetPaintedHeight > 0
      ? (parent.height - root.actualInk.height) / 2 - baselineOffset - root.actualInk.y
      : (parent.height - implicitHeight) / 2
    text: root.text
    color: root.color
    font.family: root.fontFamily
    font.pixelSize: root.renderedFontSize
    renderType: Text.NativeRendering
  }

  Rectangle {
    visible: root.debugBounds
    anchors.fill: parent
    color: "transparent"
    border.width: 1
    border.color: "#4488ff"
  }

  Rectangle {
    visible: root.debugBounds
    x: 0
    y: Math.round(root.baselineY)
    width: parent.width
    height: 1
    color: "#44ff88"
  }
}

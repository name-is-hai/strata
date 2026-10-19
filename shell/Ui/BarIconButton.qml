import QtQuick
import QtQuick.Shapes
import QtQml.Models
import Quickshell
import qs.Commons

WidgetButton {
  id: root

  property Component iconComponent: null
  property real slotSize: Style.bar.iconSlot
  property real opticalSize: Style.bar.iconSize
  // Fit native font and vector geometry to the shared square without scaling
  // rendered textures.
  property bool useSharedIconSize: true
  // Fit visible artwork into one square; slot dimensions only limit overflow.
  readonly property real paintedExtent: Math.max(1, Math.min(root.opticalSize, root.width, root.height))
  readonly property real paintedHeight: paintedExtent
  readonly property real maximumPaintedWidth: paintedExtent
  property bool debugOpticalBounds: Quickshell.env("STRATA_DEBUG_BAR_ICONS") === "1"
  // Measured against the slot, which the open-panel underline centers on.
  readonly property real opticalCenterErrorX: glyph.visible ? opticalCanvas.x + glyph.paintedCenterX - root.width / 2 : 0
  readonly property real glyphPaintedWidth: glyph.visible ? glyph.tightWidth : 0
  readonly property real glyphBaselineY: glyph.visible ? glyph.baselineY : 0
  readonly property int glyphFontSize: glyph.visible ? glyph.renderedFontSize : 0

  function customIconParts(item) {
    var parts = []
    function visit(node) {
      if (!node) return
      if (node instanceof OpticalGlyph) parts.push({item:node, kind:"glyph"})
      else if (node instanceof Text) parts.push({item:node, kind:"text"})
      else if ("iconSize" in node) parts.push({item:node, kind:"vector"})
      else for (var child of node.children) visit(child)
    }
    visit(item)
    return parts
  }

  function vectorInk(item, includeHidden) {
    var bounds = null
    function visit(node) {
      if (!includeHidden && !node.visible) return
      var geometry = [node.x, node.y, node.width, node.height, node.scale, node.rotation]
      if (node instanceof Shape || node instanceof Rectangle || node instanceof Image) {
        var rect = node instanceof Shape ? node.boundingRect : Qt.rect(0, 0, node.width, node.height)
        var corners = [node.mapToItem(item, rect.x, rect.y),
          node.mapToItem(item, rect.x + rect.width, rect.y),
          node.mapToItem(item, rect.x, rect.y + rect.height),
          node.mapToItem(item, rect.x + rect.width, rect.y + rect.height)]
        var a = Qt.point(Math.min(...corners.map(p => p.x)), Math.min(...corners.map(p => p.y)))
        var b = Qt.point(Math.max(...corners.map(p => p.x)), Math.max(...corners.map(p => p.y)))
        if (!bounds) bounds = {left:a.x, top:a.y, right:b.x, bottom:b.y}
        else {
          bounds.left = Math.min(bounds.left, a.x); bounds.top = Math.min(bounds.top, a.y)
          bounds.right = Math.max(bounds.right, b.x); bounds.bottom = Math.max(bounds.bottom, b.y)
        }
      } else for (var child of node.children) visit(child)
    }
    visit(item)
    return bounds ? Qt.rect(bounds.left, bounds.top, bounds.right - bounds.left, bounds.bottom - bounds.top)
      : Qt.rect(0, 0, item.width, item.height)
  }

  Instantiator {
    id: customParts
    model: root.customIconParts(customLoader.item)
    delegate: QtObject {
      required property var modelData
      property string sourceFamily: root.fontFamily
      property TextMetrics sourceMetrics: TextMetrics {
        font.family: sourceFamily
        font.pixelSize: Math.max(1, Math.round(root.fontSize))
        renderType: modelData.kind === "text" ? modelData.item.renderType : Text.NativeRendering
        text: modelData.kind === "text" ? modelData.item.text : ""
      }
      property TextMetrics inkMetrics: TextMetrics {
        font: modelData.kind === "text" ? modelData.item.font : Qt.font({pixelSize: 1})
        renderType: modelData.kind === "text" ? modelData.item.renderType : Text.NativeRendering
        text: modelData.kind === "text" ? modelData.item.text : ""
      }
      readonly property rect inkBounds: {
        var node = modelData.item
        // Track layout changes explicitly; mapToItem() has no change signal.
        var layout = [node.x, node.y, node.width, node.height]
        var rect
        if (modelData.kind === "glyph") rect = node.paintedRect
        else if (modelData.kind === "text") {
          var ink = FontInk.rect(node.font.family, node.font.pixelSize, node.text, inkMetrics.tightBoundingRect)
          var x = node.horizontalAlignment === Text.AlignHCenter ? (node.width - node.contentWidth) / 2
            : node.horizontalAlignment === Text.AlignRight ? node.width - node.contentWidth : 0
          rect = Qt.rect(x + ink.x, node.baselineOffset + ink.y, ink.width, ink.height)
        } else rect = root.vectorInk(node)
        var a = node.mapToItem(customLoader.item, rect.x, rect.y)
        var b = node.mapToItem(customLoader.item, rect.x + rect.width, rect.y + rect.height)
        return Qt.rect(a.x, a.y, b.x - a.x, b.y - a.y)
      }
      // Capture vector proportions before applying the size binding, avoiding
      // a feedback loop between a component's geometry and its iconSize.
      property real vectorUnitExtent: 1
      property bool vectorMeasured: false
      property Connections sourceFontConnection: Connections {
        target: modelData.kind === "text" ? modelData.item : null
        function onFontChanged() {
          if (sourceFamily !== modelData.item.font.family) sourceFamily = modelData.item.font.family
        }
      }
      Component.onCompleted: {
        if (modelData.kind === "text") sourceFamily = modelData.item.font.family
        if (modelData.kind !== "vector") return
        var node = modelData.item
        var ink = root.vectorInk(node, true)
        vectorUnitExtent = Math.max(ink.width, ink.height) / Math.max(1, node.iconSize)
        vectorMeasured = true
      }
      readonly property rect sourceInk: modelData.kind === "text"
        ? FontInk.rect(sourceFamily, sourceMetrics.font.pixelSize, sourceMetrics.text, sourceMetrics.tightBoundingRect)
        : Qt.rect(0, 0, 1, 1)
      property Binding sizeBinding: Binding {
        target: modelData.item
        property: modelData.kind === "vector" ? "iconSize" : modelData.kind === "glyph" ? "fontSize" : "font.pixelSize"
        value: {
          if (modelData.kind === "vector") return root.paintedExtent / Math.max(0.01, vectorUnitExtent)
          if (modelData.kind === "glyph") return Math.round(root.fontSize)
          var ink = sourceInk
          return Math.max(1, Math.floor(sourceMetrics.font.pixelSize * root.paintedExtent / Math.max(1, ink.width, ink.height)))
        }
        when: root.useSharedIconSize && (modelData.kind !== "vector" || vectorMeasured)
        restoreMode: Binding.RestoreBindingOrValue
      }
      property Binding heightBinding: Binding {
        target: modelData.kind === "glyph" ? modelData.item : null
        property: "targetPaintedExtent"
        value: root.paintedExtent
        when: root.useSharedIconSize && modelData.kind === "glyph"
        restoreMode: Binding.RestoreBindingOrValue
      }
      property Binding clearHeightBinding: Binding {
        target: modelData.kind === "glyph" ? modelData.item : null
        property: "targetPaintedHeight"
        value: 0
        when: root.useSharedIconSize && modelData.kind === "glyph"
        restoreMode: Binding.RestoreBindingOrValue
      }
      property Binding widthBinding: Binding {
        target: modelData.kind === "glyph" ? modelData.item : null
        property: "maximumPaintedWidth"
        value: root.maximumPaintedWidth
        when: root.useSharedIconSize && modelData.kind === "glyph"
        restoreMode: Binding.RestoreBindingOrValue
      }
    }
  }

  readonly property rect customInkBounds: {
    var left = Infinity, top = Infinity, right = -Infinity, bottom = -Infinity
    for (var i = 0; i < customParts.count; i++) {
      var part = customParts.objectAt(i)
      if (!part || !part.modelData.item.visible || part.modelData.item.opacity <= 0) continue
      var rect = part.inkBounds
      if (rect.width <= 0 || rect.height <= 0) continue
      left = Math.min(left, rect.x); right = Math.max(right, rect.x + rect.width)
      top = Math.min(top, rect.y); bottom = Math.max(bottom, rect.y + rect.height)
    }
    return isFinite(left) ? Qt.rect(left, top, right - left, bottom - top)
      : Qt.rect(0, 0, root.opticalSize, root.opticalSize)
  }
  function snapIconOffset(value) {
    var dpr = Math.max(1, root.Screen.devicePixelRatio)
    return Math.round(value * dpr) / dpr
  }

  labelVisible: false
  hasVisualContent: text !== "" || iconComponent !== null
  fontSize: Style.bar.iconFont
  fixedWidth: vertical ? -1 : slotSize
  fixedHeight: vertical ? slotSize : -1

  Item {
    id: opticalCanvas
    // Placed exactly, not anchored: centerIn snaps an even canvas in an odd slot
    // to a whole pixel, pulling every glyph off the open-panel underline.
    x: (root.width - width) / 2
    y: (root.height - height) / 2
    width: root.opticalSize
    height: root.opticalSize

    OpticalGlyph {
      id: glyph
      anchors.fill: parent
      visible: root.iconComponent === null
      text: root.text
      fontFamily: root.fontFamily
      fontSize: root.fontSize
      targetPaintedExtent: root.paintedExtent
      maximumPaintedWidth: root.maximumPaintedWidth
      color: root.active && root.useActiveColor ? root.activeColor : root.foreground
      rotation: root.textRotation
      debugBounds: root.debugOpticalBounds
    }

    Loader {
      id: customLoader
      anchors.fill: parent
      visible: root.iconComponent !== null
      sourceComponent: root.iconComponent
      // Translate native content by its ink center, instead of centering the
      // font line box. Device-pixel offsets preserve crisp glyph rendering.
      transform: Translate {
        x: root.useSharedIconSize ? root.snapIconOffset((root.opticalSize - root.customInkBounds.width) / 2 - root.customInkBounds.x) : 0
        y: root.useSharedIconSize ? root.snapIconOffset((root.opticalSize - root.customInkBounds.height) / 2 - root.customInkBounds.y) : 0
      }
    }

    Rectangle {
      visible: root.debugOpticalBounds && root.iconComponent !== null
      anchors.fill: parent
      color: "transparent"
      border.width: 1
      border.color: "#4488ff"
    }
  }

  Rectangle {
    visible: root.debugOpticalBounds
    anchors.fill: parent
    color: "transparent"
    border.width: 1
    border.color: "#ff4455"
  }
}

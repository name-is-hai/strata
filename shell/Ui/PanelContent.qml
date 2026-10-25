import QtQuick
import Quickshell

// A clipped plugin viewport must start and end on physical pixels. At a
// fractional output scale, an integer logical inset can put its left edge
// between pixels: the clip then cuts off a native Rectangle's rounded border.
// Align the host content bounds so plugins can keep their ordinary controls.
Item {
  id: root

  required property Item surface
  property real headerHeight: 0
  // Wayland's screen scale may be rounded up (2) while this window renders at
  // a fractional scale (1.25). Clipping must use the window's actual ratio.
  readonly property var panelWindow: root.QsWindow.window
  readonly property real pixelRatio: panelWindow && panelWindow.devicePixelRatio > 0
    ? panelWindow.devicePixelRatio : 1

  function snap(value) { return Math.round(value * pixelRatio) / pixelRatio }

  anchors.fill: parent
  anchors.topMargin: surface.contentTopInset + headerHeight
  anchors.bottomMargin: surface.contentBottomInset
  anchors.leftMargin: snap(surface.x + surface.contentLeftInset) - surface.x
  anchors.rightMargin: surface.x + surface.width
    - snap(surface.x + surface.width - surface.contentRightInset)
}

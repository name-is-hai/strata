import QtQuick
import QtQuick.Controls as Controls
import qs.Commons

// Shared scroll rail for Strata panels, lists and pickers. Keep the rail
// visually quiet and reserve `gutter` in content that reaches the edge.
Controls.ScrollBar {
  id: root
  property color foreground: Color.popups.text
  readonly property int thickness: Style.space(6)
  readonly property int gutter: Style.space(16)
  implicitWidth: thickness
  implicitHeight: thickness
  padding: 0
  minimumSize: 0.06
  hoverEnabled: true
  policy: Controls.ScrollBar.AsNeeded
  background: Item {}
  contentItem: Rectangle {
    implicitWidth: root.thickness
    implicitHeight: root.thickness
    radius: Math.min(width, height) / 2
    color: Util.alpha(root.foreground, root.pressed ? 0.75 : root.hovered ? 0.65 : 0.45)
    opacity: root.size < 1 && (root.active || root.hovered || root.pressed) ? 1 : 0
    Behavior on opacity {
      NumberAnimation { duration: 150 }
    }
  }
}

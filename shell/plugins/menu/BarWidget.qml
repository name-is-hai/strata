import QtQuick
import qs.Ui

BarWidget {
  id: root
  moduleName: "strata.menu"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\ue900"
    fontFamily: "strata"
    centerFigures: false
    horizontalMargin: 7.5
    onPressed: function(button) {
      if (!root.bar) return
      if (button === Qt.RightButton) root.bar.run("strata-launch-terminal")
      else root.bar.run("strata-shell shell toggle strata.menu '{\"menu\":\"root\"}'")
    }
  }
}

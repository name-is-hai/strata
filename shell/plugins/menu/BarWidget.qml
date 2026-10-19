import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "strata.menu"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: "Strata menu"
    text: "\uf30a" // Nerd Fonts: nf-linux-fedora
    onPressed: function(button) {
      if (!root.bar) return
      if (button === Qt.RightButton) root.bar.run("strata-launch-terminal")
      else root.bar.run("strata-shell shell toggle strata.menu '{\"menu\":\"root\"}'")
    }
  }
}

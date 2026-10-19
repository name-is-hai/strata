import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "strata.system-update"
  readonly property var updates: bar && bar.shell ? bar.shell.firstPartyServiceFor("strata.system-update") : null
  visible: !!updates && updates.updateAvailable
  implicitWidth: visible ? (vertical ? barSize : Style.bar.statusSlot) : 0
  implicitHeight: visible ? (vertical ? Style.bar.statusSlot : barSize) : 0
  BarIconButton {
    anchors.fill: parent
    bar: root.bar
    text: "󰚰"
    tooltipText: root.updates ? root.updates.summary + "\nClick to review · Right-click to check again" : "Strata updates"
    onPressed: function(button) {
      if (button === Qt.RightButton) { if (root.updates) root.updates.refresh(true) }
      else if (button === Qt.LeftButton) Quickshell.execDetached(["strata-launch-floating-terminal-with-presentation", "strata-update"])
    }
  }
}

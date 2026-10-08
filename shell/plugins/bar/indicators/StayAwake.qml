import QtQuick
import qs.Ui

BarIndicator {
  id: root

  readonly property var idleService: bar?.shell?.firstPartyServiceFor("strata.idle")

  active: idleService ? idleService.stayAwake : false
  activeText: "󰅶"
  inactiveText: "󰅶"
  activeTooltipText: "Allow automatic suspend"
  inactiveTooltipText: "Prevent automatic suspend"

  function toggle() {
    if (root.idleService) root.idleService.setIdleEnabled(root.active)
  }

  onPressed: function() { root.toggle() }
}

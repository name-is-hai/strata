import QtQuick
import qs.Commons
import qs.Ui

BarIndicator {
  id: root

  readonly property var idleService: bar?.shell?.firstPartyServiceFor("strata.idle")

  active: idleService ? (idleService.stayAwake || idleService.stayAwakeFailed) : false
  activeText: idleService && idleService.stayAwakeFailed ? "󰀦" : "󰅶"
  inactiveText: "󰅶"
  activeTooltipText: idleService && idleService.stayAwakeFailed
    ? "Stay Awake failed · click to retry" : "Stay Awake on · click to allow automatic sleep"
  inactiveTooltipText: "Stay Awake off · click to prevent automatic sleep"
  useActiveColor: idleService ? idleService.stayAwakeFailed : false

  function toggle() {
    if (root.idleService) root.idleService.setIdleEnabled(root.idleService.stayAwake)
  }

  onPressed: function(buttonCode) {
    if (buttonCode === Qt.LeftButton || buttonCode === Qt.RightButton) root.toggle()
  }
}

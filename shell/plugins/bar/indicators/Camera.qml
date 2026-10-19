import QtQuick
import qs.Commons
import qs.Ui

BarIndicator {
  id: root
  readonly property var privacy: bar && bar.shell ? bar.shell.firstPartyServiceFor("strata.privacy") : null
  readonly property bool inUse: !!privacy && privacy.cameras.length > 0
  readonly property bool unavailable: !!privacy && privacy.unavailable
  active: inUse || unavailable
  activeText: unavailable ? "󰒃" : "󰄀"
  inactiveText: "󰄀"
  useActiveColor: active
  activeColor: Color.urgent
  activeTooltipText: unavailable
    ? "Privacy monitoring unavailable\nDevice usage may not be detected. Retrying automatically."
    : "Camera in use\n" + (privacy ? privacy.describe("camera") : "")
  inactiveTooltipText: "Camera not in use"
  pressable: false
}

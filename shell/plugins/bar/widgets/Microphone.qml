import QtQuick
import qs.Ui
import "../indicators" as Indicators

// Compatibility widget: use the same control as the Indicators group.
BarWidget {
  id: root
  moduleName: "strata.microphone"
  readonly property var source: button.source
  readonly property bool muted: button.muted
  readonly property real volume: button.volume
  readonly property bool inUse: button.inUse
  visible: source !== null
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  function toggleMute() { button.toggleMute() }
  Indicators.Microphone {
    id: button
    anchors.fill: parent
    bar: root.bar
    alwaysVisible: true
  }
}

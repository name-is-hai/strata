import QtQuick
import qs.Ui

// Keep the configured bar entry as settings storage for existing installations.
// Stage is opened from Settings or its gestures and shortcuts, not the bar.
BarWidget {
  moduleName: "strata.stage-control"
  visible: false
  implicitWidth: 0
  implicitHeight: 0
}

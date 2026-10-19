import QtQuick
import qs.Commons

// One layout for the login greeter and the in-session lock screen.
Item {
  id: root
  property bool inputEnabled: true
  property bool powerActionPending: false
  signal suspendRequested()
  signal shutdownRequested()
  signal rebootRequested()

  // Keep each action independently anchored. QQuickItem's Row can repeatedly
  // polish an auto-sized Button here while the lock surface is being mapped.
  Button {
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Math.max(32, Math.round(Style.spacing.xxl * 2))
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: -148
    objectName: "lock-suspend"
    text: "Sleep"
    focusable: root.inputEnabled
    enabled: root.inputEnabled && !root.powerActionPending
    opacity: enabled ? 1 : 0.5
    iconText: "󰤄"
    bordered: true
    horizontalPadding: Math.round(Style.spacing.md * 1.25)
    verticalPadding: Math.round(Style.spacing.sm * 1.25)
    onClicked: root.suspendRequested()
  }

  Button {
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Math.max(32, Math.round(Style.spacing.xxl * 2))
    anchors.horizontalCenter: parent.horizontalCenter
    objectName: "lock-poweroff"
    text: "Shutdown"
    focusable: root.inputEnabled
    enabled: root.inputEnabled && !root.powerActionPending
    opacity: enabled ? 1 : 0.5
    iconText: "󰐥"
    bordered: true
    horizontalPadding: Math.round(Style.spacing.md * 1.25)
    verticalPadding: Math.round(Style.spacing.sm * 1.25)
    onClicked: root.shutdownRequested()
  }

  Button {
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Math.max(32, Math.round(Style.spacing.xxl * 2))
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: 148
    objectName: "lock-reboot"
    text: "Restart"
    focusable: root.inputEnabled
    enabled: root.inputEnabled && !root.powerActionPending
    opacity: enabled ? 1 : 0.5
    iconText: "󰜉"
    bordered: true
    horizontalPadding: Math.round(Style.spacing.md * 1.25)
    verticalPadding: Math.round(Style.spacing.sm * 1.25)
    onClicked: root.rebootRequested()
  }

}

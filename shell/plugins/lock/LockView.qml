import Quickshell
import qs.Ui

// The session owns authentication and video transport; all visual UI is shared
// with the login greeter through LockScreenView.
LockScreenView {
  username: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""
  videoFeedSource: Qt.resolvedUrl("LockFeedSurface.qml")
}

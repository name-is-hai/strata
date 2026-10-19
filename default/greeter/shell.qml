import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

ShellRoot {
  id: root

  property string mainMonitor: Quickshell.env("STRATA_MAIN_MONITOR") || ""
  property string username: Quickshell.env("STRATA_LOGIN_USER") || ""
  property string prompt: "Password"
  property string message: ""
  property bool busy: false
  property bool started: false
  property bool extraPrompt: false
  property bool secretPrompt: true
  property string pendingPassword: ""
  readonly property string greeterRoot: Quickshell.env("STRATA_GREETER_ROOT") || "/usr/share/strata/greeter"
  readonly property string activeScreenName: chooseActiveScreen()
  property string powerError: ""

  function chooseActiveScreen() {
    const screens = Quickshell.screens || []
    let available = ""
    for (let i = 0; i < screens.length; ++i) {
      if (!screens[i] || screens[i].width <= 0 || screens[i].height <= 0) continue
      if (!available) available = screens[i].name
      if (screens[i].name === mainMonitor) {
        available = mainMonitor
        break
      }
    }
    return available
  }
  onActiveScreenNameChanged: cursorMoveTimer.restart()

  Timer {
    id: cursorMoveTimer
    interval: 150
    onTriggered: {
      if (!root.activeScreenName) return
      cursorMove.running = false
      cursorMove.command = ["/usr/bin/strata-place-cursor-on-main", root.activeScreenName]
      cursorMove.running = true
    }
  }

  Process {
    id: cursorMove
    running: false
  }

  function send(event) {
    if (!bridge.running) {
      message = "Login service is unavailable"
      busy = false
      return
    }
    bridge.write(JSON.stringify(event) + "\n")
  }

  function submit(password) {
    if (busy || password.length === 0) return
    message = ""
    busy = true
    if (extraPrompt) send({type: "respond", response: password})
    else send({type: "login", username: username.trim(), password: password})
  }

  Process {
    id: bridge
    command: ["/usr/bin/strata-greetd-ipc"]
    running: true
    stdinEnabled: true
    stdout: SplitParser {
      onRead: function(line) {
        let event
        try { event = JSON.parse(line) }
        catch (e) { return }
        if (event.type === "started") {
          root.started = true
          Qt.quit()
        } else if (event.type === "prompt") {
          root.extraPrompt = true
          root.prompt = event.message || "Authentication response"
          root.secretPrompt = event.secret !== false
          root.busy = false
        } else if (event.type === "notice") {
          root.message = event.message || ""
        } else if (event.type === "error") {
          root.message = event.message || "Login failed"
          root.extraPrompt = false
          root.prompt = "Password"
          root.secretPrompt = true
          root.busy = false
        } else if (event.type === "ready") {
          root.extraPrompt = false
          root.prompt = "Password"
          root.secretPrompt = true
          root.busy = false
        }
      }
    }
    onExited: function(code) {
      if (!root.started) {
        root.message = "Login service exited (" + code + ")"
        root.busy = false
      }
    }
  }

  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: window
      required property var modelData
      screen: modelData
      anchors { top: true; bottom: true; left: true; right: true }
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.keyboardFocus: window.isMain ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
      color: Color.background
      readonly property bool isMain: modelData.name === root.activeScreenName
      onIsMainChanged: if (isMain) focusTimer.restart()
      Component.onCompleted: if (isMain) focusTimer.restart()

      Timer {
        id: focusTimer
        interval: 80
        onTriggered: if (window.isMain) loginView.forcePasswordFocus()
      }

      LockScreenView {
        id: loginView
        anchors.fill: parent
        backgroundPath: root.greeterRoot + "/background.jpg"
        username: root.username
        allowUserSwitch: true
        showForm: window.isMain
        inputEnabled: window.isMain
        authenticatingPassword: root.busy
        failureMessage: root.message
        placeholderText: root.extraPrompt ? root.prompt : "Enter Password"
        secretInput: root.secretPrompt
        passwordText: root.pendingPassword
        powerActionPending: power.running
        powerActionError: root.powerError
        onUsernameEdited: function(username) { root.username = username }
        onPasswordTextEdited: function(password) {
          root.pendingPassword = password
          if (password.length > 0) root.message = ""
        }
        onSubmitPassword: function(password) { root.submit(password) }
        onClearFailureRequested: root.message = ""
        onSuspendRequested: power.activate("Sleep", "suspend")
        onShutdownRequested: power.activate("Shutdown", "poweroff")
        onRebootRequested: power.activate("Restart", "reboot")
      }

      Process {
        id: power
        property string actionName: ""
        function activate(label, action) {
          if (running) return
          root.powerError = ""
          actionName = label
          command = ["/usr/bin/systemctl", action]
          running = true
        }
        running: false
        onExited: function(code) {
          if (code !== 0) root.powerError = actionName + " was unavailable"
        }
      }
    }
  }
}

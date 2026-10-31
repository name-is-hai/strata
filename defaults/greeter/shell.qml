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
  property string notice: ""
  property bool fingerprintAvailable: false
  property bool fingerprintPolicyPresent: false
  property bool fingerprintPolicySelected: false
  property bool editingUsername: false
  property bool fingerprintAttempt: false
  property bool passwordSubmitted: false
  property string queuedPassword: ""
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
      cursorMove.command = ["/usr/share/strata/bin/strata-place-cursor-on-main", root.activeScreenName]
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
      notice = ""
      busy = false
      return
    }
    bridge.write(JSON.stringify(event) + "\n")
  }

  // greetd has one PAM conversation. Keep typing available during a scan,
  // queue submissions until its password prompt, and never send an empty password.
  function submit(password) {
    if (password.length === 0 || passwordSubmitted || (busy && !fingerprintAttempt)) return
    fingerprintRetry.stop()
    message = ""
    passwordSubmitted = true
    if (busy && fingerprintAttempt) {
      queuedPassword = password
      notice = "Finishing fingerprint check…"
      return
    }
    notice = ""
    fingerprintAttempt = false
    busy = true
    if (extraPrompt) send({type: "respond", response: password})
    else send({type: "login", username: username.trim(), password: password})
  }

  function armFingerprint() {
    if (fingerprintAvailable && bridge.running && !busy && !started
        && !editingUsername && !pendingPassword.length && !queuedPassword.length && username.trim()) {
      fingerprintRetry.restart()
    }
  }

  function startFingerprint() {
    if (busy || started || !bridge.running || !fingerprintAvailable
        || editingUsername || pendingPassword.length || !username.trim()) return
    fingerprintRetry.stop()
    message = ""
    notice = "Touch the fingerprint reader or enter your password."
    extraPrompt = false
    fingerprintAttempt = true
    passwordSubmitted = false
    busy = true
    send({type: "login", username: username.trim()})
  }

  onFingerprintAvailableChanged: {
    if (fingerprintAvailable) armFingerprint()
    else fingerprintRetry.stop()
  }
  onUsernameChanged: armFingerprint()
  onPendingPasswordChanged: {
    if (pendingPassword.length) fingerprintRetry.stop()
    else armFingerprint()
  }

  Timer {
    id: fingerprintRetry
    interval: 1500
    onTriggered: root.startFingerprint()
  }

  function changeUser(name) {
    if (busy || username === name) return
    // The next login request cancels greetd's previous conversation before
    // creating one for this name. Never answer an old user's secret prompt.
    username = name
    pendingPassword = ""
    extraPrompt = false
    prompt = "Password"
    secretPrompt = true
    notice = ""
    message = ""
  }

  function handleAuthEvent(event) {
    if (event.type === "started") {
      started = true
      fingerprintRetry.stop()
      queuedPassword = ""
      Qt.quit()
    } else if (event.type === "prompt") {
      const wasFingerprint = fingerprintAttempt
      fingerprintAttempt = false
      passwordSubmitted = false
      extraPrompt = true
      prompt = event.message || "Authentication response"
      secretPrompt = event.secret !== false
      busy = false
      notice = ""
      message = ""
      if (wasFingerprint && queuedPassword.length && secretPrompt) {
        const password = queuedPassword
        queuedPassword = ""
        submit(password)
      } else if (wasFingerprint && secretPrompt) {
        // A mismatch/timeout falls through to password PAM. Retry only when
        // idle; preserve text already entered and leave its prompt usable.
        armFingerprint()
      }
    } else if (event.type === "notice") {
      // PAM's scan instructions are status, not a rejected password.
      notice = event.message || ""
    } else if (event.type === "error" || event.type === "ready") {
      const retryScan = fingerprintAttempt && !passwordSubmitted
      fingerprintAttempt = false
      passwordSubmitted = false
      queuedPassword = ""
      message = event.type === "error" ? (event.message || "Login failed") : ""
      extraPrompt = false
      prompt = "Password"
      secretPrompt = true
      busy = false
      notice = ""
      if (!retryScan) pendingPassword = ""
      if (retryScan) armFingerprint()
    }
  }

  function usesFingerprintPolicy(config) {
    let section = ""
    const lines = config.split("\n")
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].replace(/\s*#.*$/, "").trim()
      if (line.charAt(0) === "[") section = line.replace(/\s+/g, "")
      else if (section === "[general]" && /^service\s*=/.test(line)) {
        return /^service\s*=\s*["']strata-greetd["']\s*$/.test(line)
      }
    }
    return false
  }

  function refreshFingerprintAvailability() {
    if (!fingerprintPolicyPresent || !fingerprintPolicySelected) fingerprintAvailable = false
    else if (!fingerprintProbe.running) fingerprintProbe.running = true
  }
  onFingerprintPolicyPresentChanged: refreshFingerprintAvailability()
  onFingerprintPolicySelectedChanged: refreshFingerprintAvailability()

  FileView {
    id: fingerprintPolicy
    path: "/etc/pam.d/strata-greetd"
    watchChanges: false
    printErrors: false
    onLoaded: root.fingerprintPolicyPresent = true
    onLoadFailed: root.fingerprintPolicyPresent = false
  }

  FileView {
    path: "/etc/greetd/config.toml"
    watchChanges: false
    printErrors: false
    onLoaded: root.fingerprintPolicySelected = root.usesFingerprintPolicy(String(text()))
    onLoadFailed: root.fingerprintPolicySelected = false
  }

  Process {
    id: fingerprintProbe
    command: ["busctl", "--system", "--timeout=3s", "--json=short", "call",
      "net.reactivated.Fprint", "/net/reactivated/Fprint/Manager",
      "net.reactivated.Fprint.Manager", "GetDevices"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const reply = JSON.parse(String(text))
          root.fingerprintAvailable = root.fingerprintPolicyPresent && root.fingerprintPolicySelected
            && reply.type === "ao" && reply.data[0].length > 0
        } catch (e) { root.fingerprintAvailable = false }
      }
    }
    onExited: function(code) { if (code !== 0) root.fingerprintAvailable = false }
  }

  Process {
    id: bridge
    command: ["/usr/share/strata/bin/strata-greetd-ipc"]
    running: true
    stdinEnabled: true
    onRunningChanged: {
      if (running) root.armFingerprint()
      else fingerprintRetry.stop()
    }
    stdout: SplitParser {
      onRead: function(line) {
        let event
        try { event = JSON.parse(line) }
        catch (e) { return }
        root.handleAuthEvent(event)
      }
    }
    onExited: function(code) {
      if (!root.started) {
        root.message = "Login service exited (" + code + ")"
        root.busy = false
        root.fingerprintAttempt = false
        root.passwordSubmitted = false
        root.queuedPassword = ""
        root.notice = ""
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
        allowUserSwitch: !root.busy
        showForm: window.isMain
        inputEnabled: window.isMain
        authenticatingPassword: root.busy && (!root.fingerprintAttempt || root.passwordSubmitted)
        fingerprintConfigured: root.fingerprintAvailable
        authenticationNotice: root.notice
        failureMessage: root.message
        placeholderText: root.extraPrompt ? root.prompt : "Enter Password"
        secretInput: root.secretPrompt
        passwordText: root.pendingPassword
        powerActionPending: power.running
        powerActionError: root.powerError
        onEditingUserChanged: {
          if (!window.isMain) return
          root.editingUsername = editingUser
          if (editingUser) fingerprintRetry.stop()
          else root.armFingerprint()
        }
        onUsernameEdited: function(username) { root.changeUser(username) }
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

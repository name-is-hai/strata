import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.Ui

ShellRoot {
  id: harness
  property string password: ""
  property string user: "liam"
  property var submissions: []
  property var actions: []
  property int fingerprintRequests: 0
  property var lockView: null
  property bool failed: false
  property int captures: 0

  function check(value, message) {
    if (!value) { failed = true; throw new Error(message) }
  }
  function find(item, name) {
    if (item.objectName === name) return item
    for (var i = 0; i < item.children.length; ++i) {
      var match = find(item.children[i], name)
      if (match) return match
    }
    return null
  }
  function type(text) {
    for (var i = 0; i < text.length; ++i) check(events.keyClickChar(text[i], Qt.NoModifier, 0), "Key delivery failed")
  }
  TestEvent { id: events }
  Window {
    id: window
    visible: true
    width: 1600; height: 600
    LockScreenView {
      id: loginView
      x: 800; width: 800; height: 600
      loadBackground: false
      username: harness.user
      passwordText: harness.password
      allowUserSwitch: true
      onPasswordTextEdited: function(value) { harness.password = value }
      onUsernameEdited: function(value) { harness.user = value }
      onSubmitPassword: function(value) { harness.submissions.push(value) }
      onFingerprintLoginRequested: harness.fingerprintRequests += 1
      onClearFailureRequested: failureMessage = ""
      onSuspendRequested: harness.actions.push("suspend")
      onShutdownRequested: harness.actions.push("poweroff")
      onRebootRequested: harness.actions.push("reboot")
    }
  }
  Timer {
    interval: 300; running: true
    onTriggered: {
      try {
        var component = Qt.createComponent("file://" + Quickshell.env("STRATA_TEST_REPO") + "/shell/plugins/lock/LockView.qml")
        harness.check(component.status === Component.Ready, component.errorString())
        harness.lockView = component.createObject(window.contentItem, {width:800,height:600,loadBackground:false,username:"liam",inputEnabled:false})
        harness.check(harness.lockView !== null, "Lock wrapper failed to instantiate")
        window.requestActivate()
        loginView.forcePasswordFocus()
        var input = harness.find(loginView, "lock-password-input")
        harness.check(input && input.activeFocus, "Password input did not receive focus")
        harness.check(input.echoMode === TextInput.Password, "Password is not masked")
        harness.type("test-password")
        harness.check(harness.password === "test-password", "Password edits did not reach controller")
        events.keyClick(Qt.Key_Return, Qt.NoModifier, 0)
        harness.check(harness.submissions.length === 1 && harness.submissions[0] === "test-password" && harness.password === "", "Submit did not deliver once and clear")
        loginView.authenticatingPassword = true
        harness.check(!input.enabled && input.readOnly, "Busy input was editable")
        loginView.authenticatingPassword = false
        loginView.forcePasswordFocus()
        harness.type("clear-me")
        events.keyClick(Qt.Key_U, Qt.ControlModifier, 0)
        harness.check(harness.password === "", "Ctrl+U did not clear")
        harness.type("escape")
        events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0)
        harness.check(harness.password === "", "Escape did not clear")
        loginView.failureMessage = "Try again"
        harness.type("x")
        harness.check(loginView.failureMessage === "", "New input did not clear failure")
        harness.password = ""
        loginView.secretInput = false
        loginView.placeholderText = "Authentication response"
        harness.check(input.echoMode === TextInput.Normal, "Non-secret challenge remained masked")
        harness.type("response")
        events.keyClick(Qt.Key_Return, Qt.NoModifier, 0)
        harness.check(harness.submissions[1] === "response", "Challenge response was lost")
        loginView.secretInput = true
        harness.password = "x".repeat(120)
        harness.check(loginView.passwordDotScale < 1 && loginView.passwordDotScale > 0, "Long masked input did not fit")
        harness.password = ""
        loginView.editingUser = true
        var userInput = harness.find(loginView, "lock-username-input")
        harness.check(userInput.visible, "Username editor did not open")
        userInput.forceActiveFocus(); userInput.selectAll()
        harness.type("other-user")
        harness.check(harness.user === "other-user", "Username edit did not reach greeter")
        events.keyClick(Qt.Key_Return, Qt.NoModifier, 0)
        harness.check(!loginView.editingUser && input.activeFocus, "Username accept did not return password focus")
        loginView.fingerprintConfigured = true
        loginView.fingerprintUnavailable = true
        harness.check(harness.find(loginView,"fingerprintUnavailableNotice").visible, "Fingerprint failure notice disappeared")
        loginView.fingerprintConfigured = false
        loginView.fingerprintUnavailable = false
        var fingerprintButton = harness.find(loginView,"fingerprintLoginButton")
        harness.check(!fingerprintButton.visible,"Fingerprint login leaked into default lock UI")
        loginView.authenticationNotice = "Fingerprint not recognized. Try again."
        harness.check(harness.find(loginView,"authenticationNotice").visible,"Lock fingerprint feedback missing")
        harness.check(input.enabled && !input.readOnly,"Fingerprint feedback blocked password entry")
        harness.check(!fingerprintButton.visible,"Lock feedback exposed a manual fingerprint button")
        loginView.allowFingerprintLogin = true
        loginView.authenticationNotice = "Touch the reader"
        harness.check(fingerprintButton.visible && fingerprintButton.enabled,"Greeter fingerprint action missing")
        harness.check(harness.find(loginView,"authenticationNotice").visible,"Scan instructions missing")
        harness.check(events.mouseClick(fingerprintButton,fingerprintButton.width/2,fingerprintButton.height/2,Qt.LeftButton,Qt.NoModifier,0),"Fingerprint action click failed")
        harness.check(harness.fingerprintRequests === 1,"Fingerprint action did not reach controller")
        loginView.authenticatingPassword = true
        harness.check(!fingerprintButton.enabled,"Fingerprint action remains enabled during authentication")
        loginView.authenticatingPassword = false
        loginView.allowFingerprintLogin = false
        loginView.authenticationNotice = ""
        var names = ["lock-suspend","lock-poweroff","lock-reboot"]
        for (var i=0; i<names.length; ++i) {
          var button = harness.find(loginView,names[i])
          harness.check(events.mouseClick(button,button.width/2,button.height/2,Qt.LeftButton,Qt.NoModifier,0),"Button click failed")
        }
        harness.check(harness.actions.join(",") === "suspend,poweroff,reboot", "Power signals did not match buttons")
        loginView.powerActionPending = true
        for (var j=0; j<names.length; ++j) harness.check(!harness.find(loginView,names[j]).enabled,"Pending action did not disable button")
        loginView.powerActionPending = false
        loginView.showForm = false
        harness.check(!harness.find(loginView,"lock-clock").visible && harness.find(loginView,"lock-password-field").opacity === 0,"Background-only screen still shows form")
        loginView.showForm = true
        loginView.placeholderText = "Enter Password"
        harness.user = "liam"
        loginView.inputEnabled = false
        harness.lockView.inputEnabled = false
        harness.check(!input.enabled, "Preview input was enabled")
        renderTimer.start()
        console.warn("PASS: masked/visible prompts, submit/clear, busy/error states, user switching, fingerprint, power signals, secondary display")
      } catch(error) { console.error("FAIL: " + error); Qt.quit() }
    }
  }
  Timer {
    id: renderTimer
    interval: 100
    onTriggered: {
      var values = [harness.lockView, loginView]
      var labels = ["lock", "greeter"]
      for (var i=0; i<values.length; ++i) {
        values[i].currentTimeString = "12:34:56"
        values[i].currentDateString = "Sunday, October 18"
      }
      imageTimer.start()
    }
  }
  Timer {
    id: imageTimer
    interval: 30
    onTriggered: {
      function capture(view, label) {
        view.grabToImage(function(result) {
          if (!result.saveToFile(Quickshell.env("STRATA_TEST_OUTPUT")+"/"+label+".png")) { console.error("FAIL: screenshot failed"); Qt.quit(); return }
          harness.captures += 1
          if (harness.captures === 2) { console.warn("PASS: shared full-screen views rendered"); Qt.quit() }
        })
      }
      capture(harness.lockView, "lock")
      capture(loginView, "greeter")
    }
  }
  Timer { interval:10000; running:true; onTriggered:{console.error("FAIL: timeout");Qt.quit()} }
}

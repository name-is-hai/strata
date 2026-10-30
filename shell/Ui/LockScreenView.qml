import QtQuick
import QtQuick.Effects
import qs.Commons

Item {
  id: root

  property string username: ""
  property bool allowUserSwitch: false
  property bool editingUser: false
  property bool secretInput: true
  property url videoFeedSource: ""
  property string backgroundPath: ""
  property string videoPosterPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool fingerprintUnavailable: false
  property bool authenticatingPassword: false
  property bool allowFingerprintLogin: false
  property string authenticationNotice: ""
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool showForm: true
  property bool powerActionPending: false
  property string powerActionError: ""
  property bool loadBackground: true
  // The active power plan and Stay Awake control display-off while locked.
  // Pause video decoding whenever the display is actually blank.
  property bool displaysBlank: false
  property bool powerSaverActive: false
  property string passwordText: ""
  property bool syncingPasswordText: false
  property string currentTimeString: ""
  property string currentDateString: ""

  property string placeholderText: "Enter Password"
  readonly property int fieldWidth: 381
  readonly property int fieldHeight: 67
  readonly property int outlineThickness: 3
  readonly property int fieldFontSize: Math.round(Style.font.heading * 1.125)
  readonly property int passwordDotFontSize: Math.round(Style.font.heading * 1.33)
  readonly property int passwordDotLetterSpacing: Math.round(Style.font.heading * 0.19)
  // Space to keep clear on each side of the field for the fingerprint icon
  // (icon width plus a gap) so the centered dots never run under it.
  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 12) : 0
  // Shrink the dots to fit once the password outgrows the field, so every
  // keystroke stays visible — otherwise long passwords clip with no feedback.
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth)
    : 1
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0
  readonly property var inputBorderSpec: errorState
    ? Border.surfaceSpec("lock", "border-error", Color.lock.borderError, root.outlineThickness, "border-alpha")
    : Border.surfaceSpec("lock", "border-active", Color.lock.borderActive, root.outlineThickness, "border-alpha")

  readonly property bool video: Util.isVideoPath(root.backgroundPath)
  readonly property bool feedActive: root.videoFeedSource.toString() !== "" && root.video && root.loadBackground && !root.displaysBlank && !root.powerSaverActive

  signal usernameEdited(string username)
  signal submitPassword(string password)
  signal fingerprintLoginRequested()
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()
  signal suspendRequested()
  signal shutdownRequested()
  signal rebootRequested()

  function forcePasswordFocus() {
    if (inputEnabled && !editingUser) passwordInput.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  // Waking a DPMS-blanked display can stall the compositor for seconds while
  // the monitor modesets, so the wake key's release arrives late and client-side
  // key repeat floods the field with that character. A held key has no business
  // typing a password; only holding Backspace/Delete to clear stays useful.
  function dropsAutoRepeat(key) {
    return key !== Qt.Key_Backspace && key !== Qt.Key_Delete
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  onPasswordTextChanged: syncPasswordText()
  onAuthenticatingPasswordChanged: if (!authenticatingPassword && inputEnabled) Qt.callLater(forcePasswordFocus)
  onPlaceholderTextChanged: if (inputEnabled) Qt.callLater(forcePasswordFocus)
  onFailureMessageChanged: if (inputEnabled) Qt.callLater(forcePasswordFocus)
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  Timer {
    id: dateTimeTimer
    interval: 1000
    running: root.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      var now = new Date()
      root.currentTimeString = Qt.formatDateTime(now, "HH:mm:ss")
      root.currentDateString = Qt.formatDateTime(now, "dddd, MMMM d")
    }
  }

  // Measures the masked password at full size; passwordDotScale compares this
  // against the field width to decide how far the dots must shrink to fit.
  TextMetrics {
    id: dotMetrics
    font.family: Style.font.family
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: "●".repeat(passwordInput.text.length)
  }

  Rectangle {
    anchors.fill: parent
    color: Color.background

    BackgroundMedia {
      id: wallpaper
      objectName: "lockWallpaper"
      anchors.fill: parent
      path: root.loadBackground ? (root.video ? root.videoPosterPath : root.backgroundPath) : ""
      version: root.backgroundVersion
      // Decode only once sized, at the lock's own size: an unsized first
      // request decoded the file at its native resolution, then again once
      // sized. That size is what the lock service keeps decoded ahead of the
      // lock, so the first frame has the wallpaper.
      cached: true
      constrainDecode: true
      decodeSize: Qt.size(width, height)
    }

    MultiEffect {
      anchors.fill: wallpaper
      source: wallpaper
      autoPaddingEnabled: false
      blurEnabled: root.loadBackground && wallpaper.ready
      blur: 1.0
      blurMax: 128
      blurMultiplier: 1.25
      contrast: -0.08
    }

    // The cached poster stays behind the feed when policy pauses playback,
    // the module is unavailable, or a new connection has not received a frame.
    Loader {
      id: feedLoader
      objectName: "lockFeedLoader"
      anchors.fill: parent
      active: root.feedActive
      source: root.videoFeedSource
      visible: status === Loader.Ready
    }

    // The feed item cannot be sampled by MultiEffect on every renderer.
    // Keep video wallpapers visible and darken them slightly for legibility.
    Rectangle {
      anchors.fill: feedLoader
      visible: root.video
      color: "#22000000"
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    Column {
      id: timeDateColumn
      objectName: "lock-clock"
      visible: root.showForm
      anchors.bottom: inputField.top
      anchors.bottomMargin: Math.round(Style.spacing.xxl * 2)
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Math.round(Style.spacing.sm / 2)

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.currentTimeString
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.heading * 3.2)
        font.weight: Font.Bold
        horizontalAlignment: Text.AlignHCenter
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.currentDateString
        color: Color.lock.placeholder
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.heading * 1.25)
        horizontalAlignment: Text.AlignHCenter
      }
    }

    BorderSurface {
      id: inputField
      objectName: "lock-password-field"
      // Keep the masked input available on every locked surface: keyboard
      // focus may follow the pointer onto a background-only display. Edits
      // still update the shared password shown on the Main display.
      opacity: root.showForm ? 1 : 0
      width: Math.min(root.fieldWidth, Math.max(1, parent.width - 32))
      height: root.fieldHeight
      anchors.centerIn: parent
      color: Color.lock.background
      borderSpec: root.inputBorderSpec
      radius: Style.cornerRadius
      clip: true

      TextInput {
        id: passwordInput
        objectName: "lock-password-input"
        anchors.fill: parent
        anchors.topMargin: inputField.borderTop
        // Reserve the fingerprint icon's width on both sides so the centered
        // dots stay symmetric and never slide under the icon as they grow.
        anchors.rightMargin: inputField.borderRight + 18 + root.fingerprintReserve
        anchors.bottomMargin: inputField.borderBottom
        anchors.leftMargin: inputField.borderLeft + 18 + root.fingerprintReserve
        verticalAlignment: TextInput.AlignVCenter
        horizontalAlignment: TextInput.AlignHCenter
        activeFocusOnPress: true
        clip: true
        enabled: root.inputEnabled && !root.authenticatingPassword
        readOnly: root.authenticatingPassword
        echoMode: root.secretInput ? TextInput.Password : TextInput.Normal
        passwordCharacter: "\u25CF"
        passwordMaskDelay: 0
        color: Color.lock.text
        selectionColor: Color.lock.selection
        selectedTextColor: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: root.secretInput && text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize
        font.letterSpacing: root.secretInput && text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
        cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0
        cursorDelegate: Rectangle {
          width: 2
          color: Color.lock.text
          visible: passwordInput.cursorVisible
        }

        onTextChanged: {
          if (!root.syncingPasswordText) root.passwordTextEdited(text)
          if (text.length > 0) {
            root.wakeRequested()
          }
          if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
        }

        onAccepted: {
          var submitted = root.passwordText
          root.passwordTextEdited("")
          if (submitted.length > 0) root.submitPassword(submitted)
        }

        Keys.onPressed: function(event) {
          root.wakeRequested()
          if (event.isAutoRepeat && root.dropsAutoRepeat(event.key)) {
            event.accepted = true
            return
          }
          if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
            root.passwordTextEdited("")
            event.accepted = true
          }
        }
      }

      Text {
        textFormat: Text.PlainText
        anchors.fill: passwordInput
        text: root.authenticatingPassword ? "Checking…" : (root.failureMessage.length > 0 ? root.failureMessage : root.placeholderText)
        visible: passwordInput.text.length === 0
        color: root.authenticatingPassword ? Color.lock.text : (root.failureMessage.length > 0 ? Color.lock.textError : Color.lock.placeholder)
        font.family: Style.font.family
        font.pixelSize: root.fieldFontSize
        font.italic: !root.authenticatingPassword && root.failureMessage.length > 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }

      // Fingerprint hint pinned inside the field's right edge when a sensor is
      // enrolled, so the user knows they can touch to unlock instead of typing.
      // Matches hyprlock, which draws its fingerprint icon in the same spot.
      // A reader the shell cannot reach crosses out rather than disappears, so
      // it stops inviting touches that can never unlock.
      Text {
        id: fingerprintIcon
        objectName: "fingerprintIndicator"
        textFormat: Text.PlainText
        anchors.right: parent.right
        anchors.rightMargin: inputField.borderRight + 18
        anchors.verticalCenter: parent.verticalCenter
        visible: root.fingerprintConfigured
        text: root.fingerprintUnavailable ? "󰺱" : "󰈷"
        color: root.fingerprintUnavailable ? Color.lock.textError : Color.lock.placeholder
        font.family: Style.font.family
        font.pixelSize: Math.round(root.fieldFontSize * 1.1)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }

    TextInput {
      id: userInput
      objectName: "lock-username-input"
      width: Math.min(root.fieldWidth, Math.max(1, parent.width - 32))
      height: 32
      anchors.top: inputField.bottom
      anchors.topMargin: 14
      anchors.horizontalCenter: inputField.horizontalCenter
      visible: root.showForm && root.allowUserSwitch && root.editingUser
      enabled: root.inputEnabled && !root.authenticatingPassword
      text: root.username
      color: Color.lock.placeholder
      selectionColor: Color.lock.selection
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      horizontalAlignment: TextInput.AlignHCenter
      verticalAlignment: TextInput.AlignVCenter
      onTextEdited: root.usernameEdited(text)
      onAccepted: { root.editingUser = false; root.forcePasswordFocus() }
      Keys.onEscapePressed: { root.editingUser = false; root.forcePasswordFocus() }
      Text {
        anchors.centerIn: parent
        visible: !userInput.text.length && !userInput.activeFocus
        textFormat: Text.PlainText
        text: "Username"
        color: Color.lock.placeholder
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
    }

    Text {
      id: authenticationStatus
      objectName: "authenticationNotice"
      anchors.top: inputField.bottom
      anchors.topMargin: 14
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.min(root.fieldWidth, parent.width - 32)
      visible: root.showForm && !root.editingUser && root.authenticationNotice !== ""
      textFormat: Text.PlainText
      text: root.authenticationNotice
      color: Color.lock.placeholder
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
    }

    Button {
      objectName: "fingerprintLoginButton"
      anchors.top: authenticationStatus.visible ? authenticationStatus.bottom : inputField.bottom
      anchors.topMargin: 14
      anchors.horizontalCenter: parent.horizontalCenter
      visible: root.showForm && root.allowFingerprintLogin && !root.editingUser
      enabled: root.inputEnabled && !root.authenticatingPassword && root.username.trim() !== ""
      text: "Use fingerprint"
      foreground: Color.lock.text
      focusable: true
      bordered: true
      onClicked: root.fingerprintLoginRequested()
    }

    Text {
      objectName: "lock-username"
      anchors.left: parent.left
      anchors.leftMargin: 32
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Math.max(32, Math.round(Style.spacing.xxl * 2))
      visible: root.showForm && (root.username.length > 0 || root.allowUserSwitch)
      textFormat: Text.PlainText
      text: root.username || "Choose user"
      color: Color.lock.placeholder
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      MouseArea {
        anchors.fill: parent
        enabled: root.allowUserSwitch && root.inputEnabled && !root.authenticatingPassword
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          root.editingUser = true
          Qt.callLater(function() { userInput.forceActiveFocus(); userInput.selectAll() })
        }
      }
    }

    LockPowerActions {
      anchors.fill: parent
      visible: root.showForm
      inputEnabled: root.inputEnabled
      powerActionPending: root.powerActionPending
      onSuspendRequested: root.suspendRequested()
      onShutdownRequested: root.shutdownRequested()
      onRebootRequested: root.rebootRequested()
    }

    Text {
      objectName: "powerActionError"
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 8
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.min(parent.width - 48, 680)
      visible: root.showForm && root.powerActionError !== ""
      text: root.powerActionError
      color: Color.lock.textError
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
    }

    Text {
      objectName: "fingerprintUnavailableNotice"
      textFormat: Text.PlainText
      anchors.top: inputField.bottom
      anchors.topMargin: 18
      anchors.horizontalCenter: inputField.horizontalCenter
      visible: root.showForm && root.fingerprintConfigured && root.fingerprintUnavailable
      text: "Fingerprint reader unavailable"
      color: Color.lock.textError
      font.family: Style.font.family
      font.pixelSize: Style.font.heading
      font.italic: true
      horizontalAlignment: Text.AlignHCenter
    }
  }
}

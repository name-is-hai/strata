import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

Panel {
  id: root
  moduleName: "strata.language-input"
  ipcTarget: "strata.language-input"

  property string inputMethod: ""
  property var inputs: []
  property int fcitxState: -1
  property string toggleHotkey: ""
  property string errorText: ""
  property bool recordingHotkey: false
  property string pendingHotkey: ""

  readonly property bool fcitxRunning: fcitxState >= 0
  readonly property string languageLabel: labelFor(inputMethod || (inputs.length ? inputs[0] : "keyboard-us"))

  function labelFor(value) {
    var method = String(value || "").toLowerCase()
    if (method.indexOf("unikey") !== -1 || method.indexOf("vietnam") !== -1) return "VN"
    if (method.indexOf("pinyin") !== -1 || method.indexOf("zhuyin") !== -1 || method.indexOf("chewing") !== -1) return "ZH"
    if (method.indexOf("mozc") !== -1 || method.indexOf("anthy") !== -1) return "JP"
    if (method.indexOf("hangul") !== -1) return "KR"
    method = method.replace(/^keyboard-/, "")
    return (method || "US").slice(0, 3).toUpperCase()
  }
  function inputName(value) {
    var names = { "keyboard-us": "US keyboard", unikey: "Unikey", pinyin: "Pinyin", chewing: "Chewing", mozc: "Mozc", hangul: "Hangul" }
    return names[value] || String(value || "").replace(/^keyboard-/, "Keyboard · ")
  }
  function refresh() {
    if (!nameQuery.running) nameQuery.running = true
    if (!stateQuery.running) stateQuery.running = true
    if (!inputsQuery.running) inputsQuery.running = true
    if (!hotkeyQuery.running) hotkeyQuery.running = true
  }
  function selectInput(method) {
    if (!method || selectQuery.running) return
    errorText = ""
    selectQuery.command = ["fcitx5-remote", "-s", method]
    selectQuery.running = true
  }
  function openSettings() { Quickshell.execDetached(["fcitx5-configtool"]) }
  function modifierNames(modifiers) {
    var names = []
    if (modifiers & Qt.ControlModifier) names.push("Control")
    if (modifiers & Qt.AltModifier) names.push("Alt")
    if (modifiers & Qt.ShiftModifier) names.push("Shift")
    if (modifiers & Qt.MetaModifier) names.push("Super")
    return names
  }
  function keyName(event) {
    if (event.key === Qt.Key_Space) return "space"
    if (event.key >= Qt.Key_A && event.key <= Qt.Key_Z) return String.fromCharCode(event.key)
    if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) return String.fromCharCode(event.key)
    var special = {}
    special[Qt.Key_Escape] = "Escape"; special[Qt.Key_Return] = "Return"; special[Qt.Key_Enter] = "Enter"
    special[Qt.Key_Tab] = "Tab"; special[Qt.Key_Backspace] = "BackSpace"; special[Qt.Key_Delete] = "Delete"
    special[Qt.Key_Left] = "Left"; special[Qt.Key_Right] = "Right"; special[Qt.Key_Up] = "Up"; special[Qt.Key_Down] = "Down"
    special[Qt.Key_Home] = "Home"; special[Qt.Key_End] = "End"; special[Qt.Key_PageUp] = "Page_Up"; special[Qt.Key_PageDown] = "Page_Down"
    if (special[event.key]) return special[event.key]
    if (event.key >= Qt.Key_F1 && event.key <= Qt.Key_F35) return "F" + (event.key - Qt.Key_F1 + 1)
    return ""
  }
  function startHotkeyRecording() {
    recordingHotkey = true
    pendingHotkey = ""
    errorText = ""
    Qt.callLater(function() { hotkeyRecorder.forceActiveFocus() })
  }
  function cancelHotkeyRecording() {
    recordingHotkey = false
    pendingHotkey = ""
  }
  function captureHotkey(event) {
    var key = keyName(event)
    if (!key) return
    var modifiers = modifierNames(event.modifiers)
    if (modifiers.length === 0) {
      errorText = "Use a modifier with Space or another key"
      return
    }
    pendingHotkey = modifiers.concat([key]).join("+")
    recordingHotkey = false
  }
  function saveHotkey() {
    if (!pendingHotkey || hotkeySetQuery.running) return
    errorText = ""
    hotkeySetQuery.errors = ""
    hotkeySetQuery.command = ["strata-fcitx-hotkey", "set", pendingHotkey]
    hotkeySetQuery.running = true
  }

  Component.onCompleted: refresh()
  onOpenedChanged: if (!opened) cancelHotkeyRecording()

  Process { id: nameQuery; command: ["fcitx5-remote", "-n"]; stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.inputMethod = String(text || "").trim() } }
  Process { id: stateQuery; command: ["fcitx5-remote"]; stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.fcitxState = parseInt(String(text || "-1").trim(), 10) } }
  Process { id: inputsQuery; command: ["strata-fcitx-inputs"]; stdout: StdioCollector { waitForEnd: true; onStreamFinished: { try { root.inputs = JSON.parse(String(text || "[]")) } catch (error) { root.inputs = [] } } } }
  Process { id: hotkeyQuery; command: ["strata-fcitx-hotkey", "get"]; stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.toggleHotkey = String(text || "").trim() } }
  Process {
    id: selectQuery
    property string errors: ""
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: selectQuery.errors = String(text || "").trim() }
    onExited: function(code) { if (code !== 0) root.errorText = selectQuery.errors || "Could not switch input method"; else refreshTimer.restart() }
  }
  Process {
    id: hotkeySetQuery
    property string errors: ""
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: hotkeySetQuery.errors = String(text || "").trim() }
    onExited: function(code) {
      if (code !== 0) root.errorText = hotkeySetQuery.errors || "Could not save the Fcitx5 shortcut"
      else { root.toggleHotkey = root.pendingHotkey; root.pendingHotkey = ""; refreshTimer.restart() }
    }
  }
  Timer { id: refreshTimer; interval: 700; onTriggered: root.refresh() }
  Timer { interval: 1200; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.languageLabel
    horizontalMargin: 6
    tooltipText: root.languageLabel + " · Language & Input"
    onPressed: root.toggle()
  }

  KeyboardPanel {
    id: panel
    panelHeader: panelTitleHeader
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(410))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(610))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.recordingHotkey
      onCloseRequested: { root.cancelHotkeyRecording(); root.close() }
      Column {
        id: content
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        spacing: Style.spacing.panelGap
        PanelHero {
          id: panelTitleHeader
          parent: panel.headerContainer
          title: "Input Method"
          meta: "FCITX5"
          detail: root.languageLabel
          iconComponent: Component { Text { text: root.languageLabel; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true } }
        }
        PanelSectionHeader { text: "ACTIVE LANGUAGE" }
        Text { width: parent.width; text: root.languageLabel; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body }
        PanelSectionHeader { text: "AVAILABLE INPUT METHODS" }
        Repeater { model: root.inputs; delegate: Button { required property string modelData; width: parent.width; text: root.inputName(modelData); bordered: true; leftAlign: true; selected: root.inputMethod === modelData; enabled: root.fcitxRunning && !selectQuery.running; onClicked: root.selectInput(modelData) } }
        PanelSectionHeader { text: "INPUT SWITCH" }
        Text {
          width: parent.width
          text: root.pendingHotkey !== "" ? "Save to update the Fcitx5 shortcut" : (root.toggleHotkey ? "Fcitx5 shortcut · " + root.toggleHotkey : "Configure an Fcitx5 shortcut")
          color: Qt.darker(Color.foreground, 1.4)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
        Row {
          width: parent.width
          height: Math.max(shortcutButton.implicitHeight, saveShortcut.implicitHeight)
          spacing: Style.spacing.sm
          Button {
            id: shortcutButton
            width: parent.width - (saveShortcut.visible ? saveShortcut.width + parent.spacing : 0)
            height: parent.height
            text: root.recordingHotkey ? "Press a shortcut…" : (root.pendingHotkey || "Record input switch")
            bordered: true
            onClicked: root.recordingHotkey ? root.cancelHotkeyRecording() : root.startHotkeyRecording()
          }
          Button { id: saveShortcut; visible: root.pendingHotkey !== ""; height: parent.height; text: "Save"; bordered: true; enabled: !hotkeySetQuery.running; onClicked: root.saveHotkey() }
        }
        Text { visible: root.errorText !== ""; width: parent.width; text: root.errorText; color: Color.urgent; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
        Button { width: parent.width; text: "Open Configuration"; iconText: "󰒓"; bordered: true; onClicked: root.openSettings() }
      }
    }
    Item {
      id: hotkeyRecorder
      anchors.fill: parent
      z: 10
      enabled: root.recordingHotkey
      focus: root.recordingHotkey
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) { event.accepted = true; root.captureHotkey(event) }
    }
  }
}

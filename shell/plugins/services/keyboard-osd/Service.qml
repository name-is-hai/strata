pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import "KeyglowModel.js" as KeyglowModel

Item {
  id: root

  property var shell: null
  property string activeWindowAddress: ""
  property var layoutLabels: ({})
  property var localConfig: ({})
  property string inputMethod: ""
  property string lastMessage: ""
  readonly property var settings: KeyglowModel.pluginSettings(
    root.shell && root.shell.shellConfig ? root.shell.shellConfig : root.localConfig,
    "strata.keyboard-osd")

  function showLayout(description) {
    const payload = KeyglowModel.osdPayload(description, root.settings, root.layoutLabels)
    if (!payload) return
    const payloadJson = JSON.stringify(payload)
    root.showPayload(payloadJson)
  }

  function showPayload(payloadJson) {
    root.lastMessage = JSON.parse(payloadJson).message
    if (root.shell && root.shell.summon("strata.osd", payloadJson)) return

    // Newer shells scope third-party lifecycle calls to the plugin itself.
    // Use the public desktop command when the direct OSD call is unavailable.
    Quickshell.execDetached(["strata-shell", "shell", "summon", "strata.osd", payloadJson])
  }

  LockKeys {
    id: locks
    onTriggered: payload => root.showPayload(payload)
  }

  Component.onCompleted: labelsProcess.running = true

  // Fcitx switches input engines without changing the physical XKB layout.
  // Observe it once for the whole shell, rather than once per monitor.
  function updateInputMethod(method, displayName) {
    const next = String(method || "").trim()
    const previous = root.inputMethod
    root.inputMethod = next
    if (!next || !previous || next === previous || focusGuard.running) return
    root.showLayout(KeyglowModel.inputMethodLabel(next, displayName))
  }

  Process {
    id: inputQuery
    command: ["busctl", "--user", "--json=short", "call", "org.fcitx.Fcitx5", "/controller", "org.fcitx.Fcitx.Controller1", "CurrentInputMethodInfo"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          const data = JSON.parse(text).data
          if (Array.isArray(data) && data.length >= 2)
            root.updateInputMethod(data[0], data[1])
        } catch (error) { root.inputMethod = "" }
      }
    }
    onRunningChanged: {
      if (running) inputQueryTimeout.restart()
      else inputQueryTimeout.stop()
    }
  }

  Timer {
    interval: 250
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: if (!inputQuery.running) inputQuery.running = true
  }

  Timer {
    id: inputQueryTimeout
    interval: 2000
    onTriggered: inputQuery.running = false
  }

  ShellIpc {
    target: "keyboard-osd"
    function state(): string {
      return JSON.stringify({
        inputMethod: root.inputMethod, lastMessage: root.lastMessage,
        capsLock: locks.capsOn, numLock: locks.numOn,
        capsKnown: locks.capsKnown, numKnown: locks.numKnown,
        capsPath: locks.capsPath, numPath: locks.numPath,
        sysfs: locks.capsSysfs || locks.numSysfs
      })
    }
  }

  FileView {
    id: settingsFile
    path: Quickshell.env("HOME") + "/.config/strata/shell.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try {
        root.localConfig = JSON.parse(settingsFile.text())
      } catch (error) {
        console.warn("Keyglow: cannot parse settings:", error)
      }
    }
    onLoadFailed: root.localConfig = ({})
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      const address = KeyglowModel.activeWindow(event)
      if (address) {
        if (root.activeWindowAddress && root.activeWindowAddress !== address)
          focusGuard.restart()
        root.activeWindowAddress = address
        return
      }

      const description = KeyglowModel.physicalLayout(event)
      if (description && !focusGuard.running) root.showLayout(description)
    }
  }

  Timer {
    id: focusGuard
    interval: 200
  }

  Process {
    id: labelsProcess
    command: ["xkbcli", "list", "--load-exotic"]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.layoutLabels = KeyglowModel.layoutLabels(text)
    }
  }
}

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import "Sounds.js" as Sounds

// Notices the moments Windows has a sound for and hands each one to
// bin/strata-sounds. Nothing here knows about files or themes: this decides
// *that* something happened, and the CLI decides what it sounds like, so the
// shell, the Audio panel, hooks and your own scripts all agree.
//
// Where each event comes from:
//   bell                 Hyprland's `bell` IPC event (xdg-system-bell: kitty,
//                        GTK 4 text fields on backspace with nothing to delete)
//   authentication       Hyprland `openlayer` for the strata-polkit dialog
//   device-*             udevadm, USB devices (not their interfaces)
//   bluetooth-*          BlueZ Device1 `Connected` changes, via gdbus monitor
//   notification          Strata's notification service plays this directly
//   audio-volume-change  the default sink's volume
//   trash-empty          ~/.local/share/Trash/files going from full to empty
//   theme-change         ~/.local/state/strata/current/theme.name
//   battery-*, power-*   UPower
//   startup              strata-sounds startup (also the post-boot hook)
//   shutdown             logind PrepareForShutdown, held by a delay inhibitor
Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string pluginDir: Sounds.localPath(Qt.resolvedUrl("."))
  readonly property string cli: pluginDir + "/bin/strata-sounds"
  readonly property string configPath: (Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")) + "/strata/sounds.json"
  readonly property string stateDir: home + "/.local/state/strata"

  property var config: ({})
  property var catalogue: ({})
  property bool catalogueReady: false
  readonly property bool debug: config.debug === true

  readonly property double startedAt: Date.now()
  property double resumedAt: 0
  property var lastPlayed: ({})

  function log(message) {
    if (debug) console.log("system-sounds: " + message)
  }

  function eventOn(id) {
    return Sounds.masterOn(config) && Sounds.eventOn(config, catalogue, id)
  }

  // Hardware and daemons replay their state for a few seconds after login and
  // after waking from sleep; none of that is news.
  function settling() {
    var now = Date.now()
    return now - startedAt < 10000 || now - resumedAt < 6000
  }

  function play(id, fallback, gate) {
    if (!eventOn(gate || id) || (gate && !eventOn(id))) return
    if (Sounds.settles(id) && settling()) return
    var now = Date.now()
    if (now - (lastPlayed[id] || 0) < Sounds.minimumGap(id)) return
    lastPlayed[id] = now
    log("play " + id)
    Quickshell.execDetached([cli, "play", id].concat(fallback || []))
  }

  // ---------------------------------------------------------------- config

  FileView {
    path: root.configPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      root.config = Sounds.parseObject(text())
      root.syncShutdownInhibitor()
    }
    onLoadFailed: {
      root.config = ({})
      root.syncShutdownInhibitor()
    }
  }

  FileView {
    path: root.pluginDir + "/events.json"
    printErrors: false
    onLoaded: {
      root.catalogue = Sounds.catalogueFrom(text())
      root.catalogueReady = true
      root.syncShutdownInhibitor()
    }
  }

  Component.onCompleted: {
    // The post-boot hook normally gets here first; the CLI keeps it to once
    // per login either way, so a shell restart stays quiet.
    Quickshell.execDetached([cli, "startup"])
  }

  // -------------------------------------------------------------- Hyprland

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event.name
      var data = event.data
      if (name === "bell") root.play("bell")
      else if (name === "openlayer" && data === "strata-polkit") root.play("authentication")
      var custom = Sounds.hyprlandSound(root.config, name, data)
      if (custom) root.play(custom)
    }
  }

  // ------------------------------------------------------------------- USB

  Process {
    id: udev
    running: true
    command: ["udevadm", "monitor", "--udev", "--subsystem-match=usb/usb_device"]
    stdout: SplitParser {
      onRead: function(line) {
        var action = Sounds.udevAction(line)
        if (action === "add") root.play("device-added")
        else if (action === "remove") root.play("device-removed")
      }
    }
    onExited: restartUdev.restart()
  }

  Timer {
    id: restartUdev
    interval: 5000
    onTriggered: udev.running = true
  }

  // ------------------------------------------------------------- Bluetooth

  // BlueZ's own signals rather than a delegate per Quickshell device: a scan
  // makes devices appear and vanish by the dozen, and only Connected matters.
  Process {
    id: bluez
    running: true
    command: ["gdbus", "monitor", "--system", "--dest", "org.bluez"]
    stdout: SplitParser {
      onRead: function(line) {
        var connected = Sounds.bluezConnected(line)
        if (connected === true) root.play("bluetooth-connect")
        else if (connected === false) root.play("bluetooth-disconnect")
      }
    }
    onExited: restartBluez.restart()
  }

  Timer {
    id: restartBluez
    interval: 15000
    onTriggered: bluez.running = true
  }

  // ---------------------------------------------------------------- volume

  // Only the default output is followed. Watching every PipeWire node means a
  // delegate per node, and nodes vanishing mid-signal is exactly what has
  // crashed Quickshell's PipeWire service in the Audio panel.
  readonly property var sink: Pipewire.defaultAudioSink
  property real lastVolume: -1

  PwObjectTracker { objects: root.sink ? [root.sink] : [] }

  function rememberVolume() {
    lastVolume = sink && sink.ready && sink.audio ? sink.audio.volume : -1
  }

  onSinkChanged: Qt.callLater(rememberVolume)

  Connections {
    target: root.sink
    function onReadyChanged() { root.rememberVolume() }
  }

  Connections {
    target: root.sink && root.sink.audio ? root.sink.audio : null
    function onVolumesChanged() {
      var audio = root.sink && root.sink.ready ? root.sink.audio : null
      if (!audio) return
      var previous = root.lastVolume
      root.lastVolume = audio.volume
      if (previous < 0 || Math.abs(audio.volume - previous) < 0.004 || audio.muted) return
      root.play("audio-volume-change")
    }
  }

  // ----------------------------------------------------------------- trash

  FolderListModel {
    id: trash
    folder: "file://" + root.home + "/.local/share/Trash/files"
    showDirs: true
    showHidden: true
    showDotAndDotDot: false
    property int lastCount: -1
    onStatusChanged: {
      if (status !== FolderListModel.Ready) return
      if (lastCount > 0 && count === 0) root.play("trash-empty")
      lastCount = count
    }
  }

  // ----------------------------------------------------------------- theme

  property string desktopTheme: ""

  FileView {
    path: root.stateDir + "/current/theme.name"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      // strata-theme-set rewrites this file in place, so a read can land on
      // the truncated, empty version first.
      var name = text().trim()
      if (name === "") return
      if (root.desktopTheme !== "" && name !== root.desktopTheme) root.play("theme-change")
      root.desktopTheme = name
    }
  }

  // --------------------------------------------------------------- battery

  property int batteryAlarm: 0   // 0 quiet, 1 low has sounded, 2 critical has sounded

  function checkBattery() {
    var device = UPower.displayDevice
    if (!device || !device.isPresent || !UPower.onBattery) {
      batteryAlarm = 0
      return
    }
    var level = Math.round(Number(device.percentage || 0) * 100)
    if (level <= 5 && batteryAlarm < 2) {
      batteryAlarm = 2
      play("battery-critical")
    } else if (level <= 10 && batteryAlarm < 1) {
      batteryAlarm = 1
      play("battery-low")
    } else if (level > 12) {
      batteryAlarm = 0
    }
  }

  Connections {
    target: UPower
    function onOnBatteryChanged() {
      var device = UPower.displayDevice
      if (device && device.isPresent) root.play(UPower.onBattery ? "power-unplug" : "power-plug")
      root.checkBattery()
    }
  }

  Connections {
    target: UPower.displayDevice
    function onPercentageChanged() { root.checkBattery() }
  }

  // --------------------------------------------------- sleep and shutdown

  Process {
    id: logind
    running: true
    command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1",
      "--object-path", "/org/freedesktop/login1"]
    stdout: SplitParser {
      onRead: function(line) {
        var signal = Sounds.logindSignal(line)
        if (!signal) return
        if (signal.name === "PrepareForSleep" && !signal.active) root.resumedAt = Date.now()
        else if (signal.name === "PrepareForShutdown" && signal.active) root.farewell()
      }
    }
    onExited: restartLogind.restart()
  }

  Timer {
    id: restartLogind
    interval: 5000
    onTriggered: logind.running = true
  }

  // logind waits on a delay inhibitor (up to InhibitDelayMaxSec) before it
  // powers off, which is the window the shutdown sound plays in. The lock is
  // only taken while the Shut down sound is switched on.
  property bool shuttingDown: false

  function syncShutdownInhibitor() {
    var want = catalogueReady && eventOn("shutdown") && !shuttingDown
    if (inhibitor.running !== want) inhibitor.running = want
  }

  function farewell() {
    if (shuttingDown || !inhibitor.running) return
    shuttingDown = true
    log("shutting down")
    farewellSound.running = true
    farewellCap.restart()
  }

  function releaseShutdown() {
    farewellCap.stop()
    inhibitor.running = false
  }

  Process {
    id: inhibitor
    command: ["systemd-inhibit", "--what=shutdown", "--mode=delay", "--who=System sounds",
      "--why=Playing the shutdown sound", "sleep", "infinity"]
    // Re-take the lock if something other than us ended it.
    onExited: if (!root.shuttingDown) restartInhibitor.restart()
  }

  Timer {
    id: restartInhibitor
    interval: 5000
    onTriggered: root.syncShutdownInhibitor()
  }

  Process {
    id: farewellSound
    command: [root.cli, "play", "shutdown"]
    onExited: root.releaseShutdown()
  }

  Timer {
    id: farewellCap
    interval: 7000
    onTriggered: root.releaseShutdown()
  }
}

import QtQuick
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

BarIndicator {
  id: root
  readonly property var source: Pipewire.defaultAudioSource
  readonly property var privacy: bar && bar.shell ? bar.shell.firstPartyServiceFor("strata.privacy") : null
  readonly property bool muted: source && source.audio ? source.audio.muted : false
  readonly property real volume: source && source.audio ? source.audio.volume : 0
  readonly property bool inUse: !!privacy && privacy.microphones.length > 0
  readonly property bool appMuted: inUse && privacy.microphones.every(function(row) { return row.muted })
  readonly property bool displayMuted: muted || appMuted
  active: inUse
  activeText: displayMuted ? "󰍭" : "󰍬"
  inactiveText: "󰍬"
  activeTooltipText: (muted ? "Microphone muted" : appMuted ? "Microphone accessed (app muted)" : "Microphone in use")
    + " · " + Math.round(volume * 100) + "%"
    + (inUse ? "\n" + privacy.describe("microphone") : "")
    + "\nClick to mute/unmute · Scroll for volume · Middle-click for audio settings"
  inactiveTooltipText: source ? "Microphone · " + Math.round(volume * 100) + "% · Click to mute · Scroll for volume" : "No microphone available"
  useActiveColor: inUse && !displayMuted
  activeColor: Color.urgent
  pressable: source !== null

  PwObjectTracker { objects: root.source ? [root.source] : [] }
  function toggleMute() {
    if (!source || !source.audio) return
    var nextMuted = !source.audio.muted
    source.audio.muted = nextMuted
  }
  onPressed: function(button) {
    if (button === Qt.MiddleButton) {
      if (root.bar) root.bar.run("strata-shell shell toggle strata.audio")
    } else root.toggleMute()
  }
  onWheelMoved: function(delta) {
    if (!source || !source.audio || delta === 0) return
    var nextVolume = Math.max(0, Math.min(1, volume + (delta > 0 ? 0.05 : -0.05)))
    source.audio.volume = nextVolume
  }
}

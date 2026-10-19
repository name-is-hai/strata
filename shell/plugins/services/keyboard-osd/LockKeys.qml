// Lock-state detector owned by the Keyboard OSD plugin.
// Adapted from trinity-bytes/omarchy-lock-keys-osd; see LOCK-KEYS-LICENSE.
import QtQuick
import Quickshell.Io

Item {
  id: root

  signal triggered(string payload)

  // Resolved once at startup by discoverProcess and cached for the session.
  // Empty means no such node on this machine, which leaves the channel to
  // hyprctl. Nothing reads these before discoveryDone is true.
  property string capsPath: ""
  property string numPath: ""
  property bool discoveryDone: false
  property int capsCandidates: 0
  property int numCandidates: 0

  // A single shell glob answers both questions at once. The trigger check is
  // what separates a real lock mirror from an LED that merely shares the name:
  // only a node that offers kbd-<lock> is the one the kernel drives.
  // Single-quoted so the shell keeps its own double quotes, and no literal
  // Unicode or path is baked in.
  readonly property string discoveryCommand: 'for n in capslock numlock; do for p in /sys/class/leds/*::$n; do if [ -r "$p/trigger" ] && grep -qw "kbd-$n" "$p/trigger" 2>/dev/null; then echo "$n|$p/brightness"; fi; done; done'

  // One glyph per lock, so the icon says WHICH lock changed. A single generic
  // toggle glyph had to stand in for both locks and therefore told you nothing
  // the message did not already say. The state is left to the message: the
  // glyph identifies the lock, "ON"/"OFF" reports the transition.
  //
  // Built by codepoint so no literal Unicode lands in this file, and verified
  // against the cmap of the font the shell resolves `monospace` to -- a codepoint
  // the font lacks would render as tofu. Unknown icon names are rendered
  // verbatim by the OSD, which is what makes a raw glyph work at all.
  // 0xF0A9B = nf-md-caps_lock (an A in a box), 0xF03A0 = nf-md-numeric (123).
  // Both live above U+FFFF, so fromCodePoint is required: fromCharCode keeps
  // only the low 16 bits and would yield U+0A9B / U+03A0 instead.
  readonly property string glyphCaps: String.fromCodePoint(0xF0A9B)
  readonly property string glyphNum: String.fromCodePoint(0xF03A0)
  readonly property int osdDuration: 1200

  // Current state, exposed so a bar widget can bind to it later.
  property bool capsOn: false
  property bool numOn: false
  // Whether each lock has a baseline yet. The first reading of each only
  // establishes that baseline -- a login must not announce a state nobody
  // toggled.
  property bool capsKnown: false
  property bool numKnown: false
  // Whether the sysfs channel is still readable. A node that cannot be read is
  // reported once and then left alone; the reconcile keeps working on its own.
  property bool capsSysfs: true
  property bool numSysfs: true

  property bool reconcilePending: false
  property string reconcileFailure: ""
  property bool capsDisagreed: false
  property bool numDisagreed: false
  // ------------------------------------------------------------ state funnel

  // The only place a lock value is compared against the one already held, by
  // either the sysfs poll or the reconcile. Keeping the comparison in one
  // place is what stops the two paths announcing the same transition twice.
  function applyLockState(channel, next) {
    if (channel === "caps") {
      if (!root.capsKnown) {
        root.capsKnown = true
        root.capsOn = next
        return
      }
      if (root.capsOn === next) return
      root.capsOn = next
      root.enqueueOsd(root.lockPayload("Caps Lock", root.glyphCaps, next))
      return
    }

    if (!root.numKnown) {
      root.numKnown = true
      root.numOn = next
      return
    }
    if (root.numOn === next) return
    root.numOn = next
    root.enqueueOsd(root.lockPayload("Num Lock", root.glyphNum, next))
  }

  // A non-empty message is what puts the OSD in message mode, and message mode
  // is what removes the progress bar -- so value/progressText are deliberately
  // absent rather than sent empty. The glyph identifies the lock and the
  // message carries the state, so no separate on/off icon pair is needed.
  function lockPayload(label, glyph, on) {
    return JSON.stringify({
      icon: glyph,
      message: label + (on ? " ON" : " OFF"),
      duration: root.osdDuration
    })
  }

  function enqueueOsd(payload) { root.triggered(payload) }

  // --------------------------------------------------------- path discovery

  // The first candidate wins and a second one is only counted. A machine with
  // two LED-capable keyboards has one node per device -- the kernel mirrors
  // each device's own lock -- and following all of them would mean announcing
  // transitions nobody made. Rather than guess, the first is used and the
  // ambiguity is reported once, in the startup line.
  function noteCandidate(channel, path) {
    if (channel === "caps") {
      if (root.capsCandidates === 0) root.capsPath = path
      root.capsCandidates++
    } else {
      if (root.numCandidates === 0) root.numPath = path
      root.numCandidates++
    }
  }

  // Idempotent: the stall timer calls it too, and a discovery that answers
  // late must not overwrite an already-decided result.
  function finishDiscovery() {
    if (root.discoveryDone) return
    root.discoveryDone = true
    discoverStallTimer.stop()

    // A channel with no node is disabled here rather than waiting for a
    // FileView to fail on an empty path, so hyprctl takes over on the same tick
    // the answer arrives.
    if (!root.capsPath) root.disableChannel("caps", "any /sys/class/leds/*::capslock node")
    if (!root.numPath) root.disableChannel("num", "any /sys/class/leds/*::numlock node")

    // Explicit rather than relying on the path binding: this is the first read
    // of the session, and it must not wait for the 100ms timer to notice.
    if (root.capsSysfs) capsFile.reload()
    if (root.numSysfs) numFile.reload()
    root.reconcile()

    if (root.capsCandidates > 1 || root.numCandidates > 1) {
      console.warn("lock-keys-osd: more than one LED lock source found, following only the first")
    }
    console.log("lock-keys-osd: watching " + (root.capsPath || "<none, hyprctl only>")
      + " and " + (root.numPath || "<none, hyprctl only>")
      + " every 100ms, reconciling against hyprctl every 5s")
  }

  Process {
    id: discoverProcess
    command: ["bash", "-c", root.discoveryCommand]
    onRunningChanged: {
      if (running) {
        discoverStallTimer.restart()
        return
      }
      discoverStallTimer.stop()
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
          var line = lines[i].trim()
          var sep = line.indexOf("|")
          if (sep < 1) continue
          var name = line.substring(0, sep)
          if (name === "capslock") root.noteCandidate("caps", line.substring(sep + 1).trim())
          else if (name === "numlock") root.noteCandidate("num", line.substring(sep + 1).trim())
        }
        root.finishDiscovery()
      }
    }
  }

  // A discovery that never returns would leave every channel waiting forever,
  // which is indistinguishable from a machine with no lock mirror. Give up on
  // it and let hyprctl answer instead.
  Timer {
    id: discoverStallTimer
    interval: 3000
    onTriggered: {
      discoverProcess.running = false
      root.finishDiscovery()
    }
  }

  // ------------------------------------------------------------- sysfs reads

  // Called from onLoaded only. reload() returns before its job has run, so a
  // text() read straight after it is the previous tick's value.
  function readLockSample(channel, raw, path) {
    var value = raw === undefined || raw === null ? "" : String(raw).trim()
    if (value !== "0" && value !== "1") {
      root.disableChannel(channel, path)
      return
    }
    root.applyLockState(channel, value === "1")
  }

  // One warning per channel, ever. Print errors are off on the FileView so a
  // node that does not exist cannot turn the 100ms poll into a log flood, and
  // the channel is marked dead so the poll stops reloading it.
  //
  // Disabled channels are sticky by design, so this must stay silent until
  // discovery has ruled: the FileViews exist with an empty path until then, and
  // failing one now would kill a channel that is about to be found.
  function disableChannel(channel, path) {
    if (!root.discoveryDone) return
    if (channel === "caps") {
      if (!root.capsSysfs) return
      root.capsSysfs = false
    } else {
      if (!root.numSysfs) return
      root.numSysfs = false
    }
    console.warn("lock-keys-osd: cannot read " + path + ", " + channel + " detection disabled")
  }

  // inotify does not fire on sysfs, so changes are watched by re-reading.
  FileView {
    id: capsFile
    path: root.capsPath
    watchChanges: false
    printErrors: false
    onLoaded: root.readLockSample("caps", text(), root.capsPath)
    onLoadFailed: root.disableChannel("caps", root.capsPath)
  }

  FileView {
    id: numFile
    path: root.numPath
    watchChanges: false
    printErrors: false
    onLoaded: root.readLockSample("num", text(), root.numPath)
    onLoadFailed: root.disableChannel("num", root.numPath)
  }

  Timer {
    interval: 100
    running: root.discoveryDone && (root.capsSysfs || root.numSysfs)
    repeat: true
    onTriggered: {
      if (root.capsSysfs) capsFile.reload()
      if (root.numSysfs) numFile.reload()
    }
  }

  // ------------------------------------------------------- hyprctl reconcile

  // hyprctl is a fallback, never an override. Its capsLock/numLock are per-device
  // fields, so "any device reports true" can latch true on a virtual or
  // hotplugged device while the real lock is off; letting that win would fight
  // the 100ms sysfs poll and announce a flip-flop every reconcile. A live sysfs
  // channel is the kernel's own mirror of the device that received the keypress,
  // so it is strictly the better evidence. While both are live the reconcile is
  // diagnostics only: it warns once if they disagree and announces nothing.
  function applyReconcile(hyprCaps, hyprNum) {
    root.capsDisagreed = root.noteDisagreement("Caps Lock", root.capsSysfs, root.capsKnown, root.capsDisagreed, hyprCaps, root.capsOn)
    root.numDisagreed = root.noteDisagreement("Num Lock", root.numSysfs, root.numKnown, root.numDisagreed, hyprNum, root.numOn)
    if (!root.capsSysfs) root.applyLockState("caps", hyprCaps)
    if (!root.numSysfs) root.applyLockState("num", hyprNum)
  }

  // Warn once per disagreement, not once per poll. A disabled sysfs channel is
  // not a disagreement: hyprctl is then the only source and there is nothing
  // for it to contradict.
  //
  // On a machine where a virtual or hotplugged device latches true, this fires
  // routinely and correctly: hyprctl's per-device aggregate really does
  // disagree, and the answer is to keep believing sysfs. The wording has to say
  // which source won, because an earlier revision claimed the opposite of what
  // the code does.
  function noteDisagreement(label, sysfsLive, known, flagged, reported, held) {
    if (!sysfsLive || !known || reported === held) return false
    if (flagged) return true
    console.warn("lock-keys-osd: sysfs reports " + label + " " + (held ? "on" : "off")
      + " but hyprctl reports " + (reported ? "on" : "off")
      + "; keeping sysfs, hyprctl is per-device and only a fallback")
    return true
  }

  function anyDeviceTrue(devices, key) {
    for (var i = 0; i < devices.length; i++) {
      if (devices[i] && devices[i][key] === true) return true
    }
    return false
  }

  function reconcile() {
    if (reconcileProcess.running) {
      reconcilePending = true
      return
    }
    reconcilePending = false
    reconcileProcess.running = true
  }

  // One line per distinct failure, so a hyprctl that is simply not answering
  // cannot turn the 5s poll into a log flood.
  function noteReconcileFailure(reason) {
    if (root.reconcileFailure === reason) return
    root.reconcileFailure = reason
    console.warn("lock-keys-osd: reconcile skipped, " + reason)
  }

  Process {
    id: reconcileProcess
    command: ["hyprctl", "-j", "devices"]
    onRunningChanged: {
      if (running) {
        reconcileStallTimer.restart()
        return
      }

      reconcileStallTimer.stop()
      if (root.reconcilePending) root.reconcile()
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var devices
        try {
          devices = JSON.parse(text || "{}").keyboards
        } catch (e) {
          root.noteReconcileFailure("hyprctl output was not JSON")
          return
        }

        // A query the watchdog killed reports nothing at all, and an empty
        // string parses into the same shape a seat with no keyboards would.
        // Only a reading that reached hyprctl and listed real devices gets to
        // speak for the seat -- otherwise a keyboard-less or broken reading
        // would read as "every lock is off" and announce a change nobody made.
        if (!Array.isArray(devices) || devices.length === 0) {
          root.noteReconcileFailure("hyprctl listed no keyboard devices")
          return
        }

        root.reconcileFailure = ""
        root.applyReconcile(
          root.anyDeviceTrue(devices, "capsLock"),
          root.anyDeviceTrue(devices, "numLock")
        )
      }
    }
  }

  // A hyprctl that never returns would hold the one Process forever and no
  // later reading could get through, so give up on it and ask again next tick.
  Timer {
    id: reconcileStallTimer
    interval: 5000
    onTriggered: {
      reconcileProcess.running = false
      root.noteReconcileFailure("hyprctl timed out")
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.reconcile()
  }

  Component.onCompleted: discoverProcess.running = true
}

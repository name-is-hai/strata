import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "CenterModel.js" as CenterModel
import "Model.js" as Model
import "../Security.js" as Security

Item {
  id: root
  required property var service
  property var removed: ({})
  property double lastSeen: 0
  property bool loaded: true
  property string loadError: ""
  property string removalError: ""
  property string focusError: ""
  readonly property bool dndBusy: false
  readonly property string dndError: ""
  readonly property bool doNotDisturb: service.doNotDisturb
  signal entryAdded(var entry)
  signal entriesReset()
  signal browserIconsUpdated()
  signal focusCompleted()

  property var entries: []
  property string entriesSignature: ""
  property var knownKeys: ({})
  function scheduleRefresh() { if (!refreshTimer.running) refreshTimer.start() }
  function refreshEntries() {
    var rows = []
    for (var i = 0; i < service.toastModel.count; i++) {
      var row = Object.assign({}, service.toastModel.get(i))
      row.sender_image = service.senderImageFor(row.key, row.image, service.senderImageRevision)
      rows.push(row)
    }
    var next = CenterModel.entries(rows.concat(service.historyRows, service.heldRows, service.recentRows), removed)
    var signature = JSON.stringify(next)
    if (signature === entriesSignature) return
    entriesSignature = signature
    var previouslyLoaded = Object.keys(knownKeys).length > 0
    var added = next.filter(function(row) { return !knownKeys[row.key] })
    var keys = ({})
    next.forEach(function(row) { keys[row.key] = true })
    knownKeys = keys
    entries = next
    entriesReset()
    if (previouslyLoaded && added.length) entryAdded(added[0])
  }
  Timer { id: refreshTimer; interval: 100; onTriggered: root.refreshEntries() }
  Connections {
    target: root.service
    function onHistoryRevisionChanged() { root.scheduleRefresh() }
    function onRecentRevisionChanged() { root.scheduleRefresh() }
    function onHeldRevisionChanged() { root.scheduleRefresh() }
    function onLayoutRevisionChanged() { root.scheduleRefresh() }
    function onSenderImageRevisionChanged() { root.scheduleRefresh() }
  }
  onRemovedChanged: scheduleRefresh()
  Component.onCompleted: scheduleRefresh()
  readonly property var unreadState: Model.unreadState(entries, lastSeen)
  readonly property int unread: unreadState.unread
  readonly property bool hasCriticalUnread: unreadState.hasCriticalUnread
  function load() { service.refreshHistory(); scheduleRefresh() }
  function toggleDnd() { service.setDoNotDisturb(!service.doNotDisturb) }
  function markSeen() { lastSeen = Date.now(); seenFile.setText(JSON.stringify({lastSeen:lastSeen}) + "\n") }
  function faviconSource(row) {
    var path = row && row.original ? String(row.original.stored_image || "") : ""
    return path.charAt(0) === "/" ? "file://" + path : ""
  }
  // The daemon already resolves icons for live and archived rows. Requesting
  // them while rebuilding the view would feed icon updates back into entries.
  function warmBrowserIcons(rows) {}
  function remove(key) { removeMany([key]) }
  function removeMany(keys) {
    var next = Object.assign({}, removed)
    keys.forEach(function(key) { next[key] = true })
    removed = next
    service.forgetNotifications(keys)
  }
  function clearAll() { removeMany(entries.map(function(row) { return row.key })) }
  function focusNotification(row, useDefault) {
    if (!row || !row.original) return
    focusError = ""
    var original = row.original
    if (useDefault && service.rowIndexFor(row.key) >= 0) {
      service.activate(row.key); focusCompleted(); return
    }
    var argv = useDefault ? Security.parseNotificationExecArgv(original.execArgv) : null
    if (argv) { service.runExecArgv(argv); focusCompleted(); return }
    var win = service.windowForPid(original.senderPid) || service.windowForSource(original.source || original.app)
    if (win) { service.focusWindow(win); focusCompleted(); return }
    focusError = "No open window was found for this notification."
  }
  FileView {
    id: seenFile
    path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/strata/notifications/center-seen.json"
    printErrors: false
    onLoaded: { try { root.lastSeen = Number(JSON.parse(text()).lastSeen) || 0 } catch (error) {} }
  }
}

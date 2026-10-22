pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

import "Model.js" as Model
import "BrowserIdentity.js" as BrowserIdentity
import "Translations.js" as Translations
import "Preferences.js" as Preferences
import "components"

// Foamy Notification Center adapted for Strata. The existing notification
// daemon owns delivery, history, actions, and quiet state; this panel presents
// that shared state without a second daemon or a second archive watcher.
// Upstream revision and licenses are retained beside this file.
//
// Glyphs are \u escapes rather than literal characters, so the source survives
// editors and patches that mangle private-use codepoints.
Panel {
  id: root
  objectName: "notificationCenterPanel"

  function open() {
    preparePopup()
    // Build and lay out the list before mapping so the first frame has its final height.
    if (rowsDirty) rebuild(true)
    if (list) list.forceLayout()
    controller.show()
  }

  moduleName: "strata.notifications"
  ipcTarget: "strata-notification-center"
  manageIpc: false
  ShellIpc {
    enabled: root.opened
    target: "notification-center"
    function settings(): string { root.openSettings(); return "ok" }
    function options(page: string): string {
      if (["main", "snooze", "sources"].indexOf(page) < 0) return "invalid"
      root.showOptions(page)
      return "ok"
    }
    function state(): string { return JSON.stringify({open:root.opened,settings:root.editingSettings,entries:root.entries.length,rows:root.rows.length,error:root.settingsError}) }
  }

  readonly property var service: bar && bar.shell ? bar.shell.firstPartyServiceFor("strata.notifications") : null
  SettingsBinding { owner: root; service: root.service }

  readonly property color foreground: Color.popups.text
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // ----------------------------------------------------------------- settings

  readonly property int panelWidth: setting("panelWidth", 420)
  readonly property int listHeight: setting("listHeight", 0)
  readonly property string badge: setting("badge", "Highlight")
  readonly property string clickAction: setting("clickAction", "Auto")
  readonly property bool compact: setting("compact", false)
  readonly property bool useBrowserFavicons: setting("useBrowserFavicons", true)
  readonly property string browserGrouping: setting("browserGrouping", "browser")
  onBrowserGroupingChanged: { expandedGroups = ({}); rebuild() }
  onUseBrowserFaviconsChanged: rebuild()
  readonly property bool showBody: setting("showBody", true)
  readonly property bool showPreview: setting("showPreview", true)

  // ------------------------------------------------------------- the service
  //
  readonly property string language: Translations.language(setting("language", "system"), Qt.locale().name)
  function tr(label, value) { return Translations.text(label, language, value) }

  readonly property bool dnd: store ? store.doNotDisturb : false
  function toggleDnd() { if (store) store.toggleDnd() }
  readonly property bool hasSnoozes: !!root.service && root.service.anySnooze
  onHasSnoozesChanged: if (!hasSnoozes && moreMenu.page === "sources") moreMenu.close()
  function showOptions(page) {
    if (page === "sources" && !hasSnoozes) return
    if (moreMenu.visible) moreMenu.page = page
    else { moreMenu.requestedPage = page; moreMenu.open() }
  }

  function snoozeTimeLeft(until) {
    var minutes = Math.max(0, Math.ceil((Number(until) * 1000 - root.now) / 60000))
    if (minutes === 0) return root.tr("Resuming…")
    var hours = Math.floor(minutes / 60)
    var remaining = minutes % 60
    var duration = hours > 0 ? hours + "h" + (remaining ? " " + remaining + "m" : "") : minutes + "m"
    return root.tr("%1 left", duration)
  }

  component SnoozedSourceRow: Button {
    id: sourceRow
    required property string sourceKey
    required property string sourceLabel
    required property double snoozedUntil
    readonly property string timeLeft: root.snoozeTimeLeft(snoozedUntil)
    height: Style.space(30)
    tooltipText: sourceLabel + " · " + timeLeft
    Accessible.name: tooltipText
    focusable: true
    foreground: root.foreground
    onClicked: { root.service.unsnooze(sourceKey); moreMenu.close() }

    Text {
      anchors.left: parent.left
      anchors.leftMargin: Style.space(10)
      anchors.right: remainingTime.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      text: sourceRow.sourceLabel
      textFormat: Text.PlainText
      elide: Text.ElideRight
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      color: root.foreground
    }
    Text {
      id: remainingTime
      anchors.right: parent.right
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      text: sourceRow.timeLeft
      textFormat: Text.PlainText
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      color: Util.alpha(root.foreground, 0.65)
    }
  }

  property bool editingSettings: false
  property string settingsError: ""
  readonly property var popupSettings: root.settings
  readonly property bool popupPluginInstalled: !!root.service
  readonly property bool popupSettingsAvailable: !!root.service
  readonly property bool popupSettingsLoading: false
  readonly property var preferenceActive: null

  function openSettings() {
    moreMenu.close()
    endSearch()
    editingSettings = true
    settingsError = ""
    settingsPane.resetScroll()
    Qt.callLater(function() { if (root.opened) settingsPane.focusBack() })
  }
  function closeSettings() {
    editingSettings = false
    Qt.callLater(function() { if (root.opened) moreButton.forceActiveFocus() })
  }
  function savePreference(scope, key, value) {
    if (!Preferences.valid(scope, key, value)) { settingsError = "Invalid setting."; return }
    if (!bar || !bar.shell || typeof bar.shell.updateEntryInline !== "function") {
      settingsError = "Settings service unavailable."; return
    }
    var next = Object.assign({}, root.settings)
    next.id = root.moduleName
    next[key] = value
    bar.shell.updateEntryInline(root.moduleName, next)
    root.settings = next
    settingsError = ""
  }

  // ------------------------------------------------------------- the store
  //
  // The archive is a shell service, not a child of this widget. Omarchy
  // builds a bar per monitor, and a Process in here would be one watcher
  // per screen: unread and clear would stick to whichever copy you clicked.
  readonly property var store: root.service ? root.service.center : null

  onStoreChanged: {
    // Let dependent bindings and the row model finish initializing first.
    Qt.callLater(function() { if (root) { root.pushSettings(); root.rebuild() } })
  }

  function pushSettings() { if (store) store.load() }

  Connections {
    target: root.store
    function onEntryAdded(entry) { root.handleEntryAdded(entry) }
    function onEntriesReset() { root.rebuild() }
    function onBrowserIconsUpdated() { root.rebuild() }
  }

  // -------------------------------------------------------------------- state

  readonly property var entries: store ? store.entries : []
  property string filter: ""
  // What the rows are marked against. Opening the center makes everything in
  // it read, so marking against `lastSeen` would mean the list never once
  // shows you which of these you had not seen, because the marks would be gone by the
  // time it finished drawing. This holds the reading from the moment before
  // you opened it, which is the question you were asking.
  property double readMark: 0
  readonly property bool loaded: store ? store.loaded : false
  property bool searching: false
  property double now: Date.now()

  readonly property int unread: store ? store.unread : 0
  readonly property bool hasCriticalUnread: store ? store.hasCriticalUnread : false
  readonly property double lastSeen: store ? store.lastSeen : 0

  Timer {
    interval: 30000
    running: root.opened
    repeat: true
    triggeredOnStart: true
    onTriggered: root.now = Date.now()
  }

  function startSearch() {
    searching = true
    Qt.callLater(function() { if (root.opened && root.searching && search) search.forceActiveFocus() })
  }

  function endSearch() {
    searching = false
    filter = ""
    if (search) { search.text = ""; search.pasteError = "" }
    Qt.callLater(function() { if (root.opened && keyCatcher) keyCatcher.forceActiveFocus() })
  }

  Connections {
    target: root.store
    function onFocusCompleted() { root.close() }
  }

  function remove(key) {
    if (store) store.remove(key)
  }

  function clearAll() {
    if (store) store.clearAll()
  }

  function handleEntryAdded(entry) {
    if (!entry || !entry.key) return
    if (root.opened && store) store.markSeen()
    rebuild()
    if (root.opened && list && list.atYBeginning) Qt.callLater(function() {
      if (root.opened && list) list.positionViewAtBeginning()
    })
  }

  // ----------------------------------------------------------------- the list

  readonly property NotificationList list: listLoader.item
  readonly property real listAvailableHeight: {
    var chrome = header.height + (removalError.visible ? removalError.implicitHeight : 0)
      + content.spacing * (1 + Number(removalError.visible)) + Style.space(10)
    return Math.max(Style.space(100), popup.usableCardHeight - popup.verticalContentInset - chrome)
  }
  property bool rowsDirty: true
  property var rows: []
  property var expandedGroups: ({})
  property int cursorIndex: -1
  property bool cursorDismiss: false
  property bool keyboardNavigation: false

  function rebuild(forOpening) {
    // The archive and unread count stay live; display groups are needed only while open.
    if (!root.opened && forOpening !== true) { rowsDirty = true; return }
    rowsDirty = false
    var focused = cursorIndex >= 0 && cursorIndex < rows.length ? rows[cursorIndex].id : ""
    var next = Model.stackRows(entries, expandedGroups, filter, browserGrouping, BrowserIdentity)
    var index = next.findIndex(function(row) { return row.id === focused })
    var headers = next.filter(function(row) { return row.kind === "header" })
    headers.forEach(function(row) {
      row.group.favicon = root.useBrowserFavicons && store ? store.faviconSource(row.group.iconEntry) : ""
    })
    rows = next
    if (useBrowserFavicons && store) store.warmBrowserIcons(headers.map(function(row) { return row.group.iconEntry }).filter(Boolean))
    cursorIndex = index >= 0 ? index : Math.min(cursorIndex, rows.length - 1)
  }

  function toggleGroup(key) {
    var next = Object.assign(Object.create(null), expandedGroups)
    next[key] = !next[key]
    expandedGroups = next
    rebuild()
  }

  function removeGroup(group) {
    if (store) store.removeMany(group.entries.map(function(entry) { return entry.key }))
  }

  function moveCursor(dx, dy) {
    if (rows.length === 0) return
    keyboardNavigation = true
    if (dy) {
      cursorIndex = Math.max(0, Math.min(rows.length - 1, cursorIndex + dy))
      cursorDismiss = false
    } else {
      if (cursorIndex < 0) cursorIndex = 0
      cursorDismiss = dx > 0
    }
    list.positionViewAtIndex(cursorIndex, ListView.Contain)
  }

  function activateCursor(removeOnly) {
    if (cursorIndex < 0 || cursorIndex >= rows.length) return
    var row = rows[cursorIndex]
    if (removeOnly || cursorDismiss) {
      if (row.kind === "header") removeGroup(row.group)
      else remove(row.entry.key)
    } else if (row.kind === "header") {
      if (row.group.entries.length > 1) toggleGroup(row.group.key)
    } else activate(row.entry)
  }

  onFilterChanged: rebuild()

  // --------------------------------------------------------------- activating

  function activate(row) {
    if (!row || clickAction === "Nothing") return
    if (store) store.focusNotification(row, clickAction === "Auto")
  }

  // ---------------------------------------------------------------- lifecycle

  Component.onCompleted: pushSettings()

  onOpenedChanged: {
    // Action feedback belongs to this panel visit, not the persistent archive.
    if (store) store.focusError = ""
    if (!opened) {
      moreMenu.close()
      editingSettings = false
      searching = false
      filter = ""
      if (search) { search.text = ""; search.pasteError = "" }
      return
    }
    now = Date.now()
    keyboardNavigation = false
    cursorIndex = -1
    cursorDismiss = false
    if (store) store.load()
    readMark = lastSeen
    if (store) store.markSeen()
    if (rowsDirty) rebuild()
  }

  // --------------------------------------------------------------------- bar

  property bool slotHovered: false
  readonly property bool revealed: Preferences.indicatorVisible(root.settings, root.unread, slotHovered, opened)
  // Keep a stable hover target while the bell is concealed.
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    concealed: !root.revealed
    interactive: root.revealed
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    bar: root.bar

    // A bell, and a bell with a line through it while notifications are
    // silenced. The second is the same glyph the shell's own DND indicator
    // uses, so the bar never shows two different pictures of one state.
    // U+F009B (bell-off) and U+F009A (bell), written as surrogate pairs so the
    // source survives editors that mangle private-use codepoints. The first is
    // the glyph the shell's own DND indicator uses, so the bar never shows two
    // different pictures of one state.
    text: root.dnd ? "\uDB80\uDC9B" : "\uDB80\uDC9A"
    dimmed: root.dnd

    // Unread notifications use the theme's red, independently of the bar's
    // active color. Hover with no unread notifications keeps the normal bell.
    active: root.badge === "Highlight" && root.unread > 0
    activeColor: Color.urgent
    tooltipText: {
      if (root.dnd) return root.unread > 0
        ? root.tr("Silenced · %1 new", root.unread) : root.tr("Notifications silenced")
      if (root.unread === 1) return root.tr("1 new notification")
      if (root.unread > 1) return root.tr("%1 new notifications", root.unread)
      return root.tr("Notifications")
    }

    onPressed: function(b) {
      // Right-click silences without opening anything, because deciding you
      // want quiet and wanting to read the backlog are opposite impulses.
      if (b === Qt.RightButton) {
        root.toggleDnd()
        return
      }
      root.toggle()
    }
  }

  // Where the panel hangs from: a zero-width point far past the right edge of
  // any screen. Invisible, in the layout for nothing, and read only for its
  // position; see the anchor comment on the panel itself.


  // The Dot marker, drawn over the bell rather than beside it: a bar that
  // changes width every time a message arrives is a bar that twitches all day.
  Rectangle {
    id: dot
    visible: root.revealed && root.badge === "Dot" && root.unread > 0
    anchors.right: button.right
    anchors.rightMargin: Style.space(6)
    anchors.top: button.top
    anchors.topMargin: Style.space(10)
    width: Style.space(6)
    height: width
    radius: width / 2
    color: root.hasCriticalUnread ? root.urgent : Color.accent
  }

  Rectangle {
    id: countBadge
    visible: root.revealed && root.badge === "Count" && root.unread > 0
    anchors.right: button.right
    anchors.rightMargin: Style.space(1)
    anchors.top: button.top
    anchors.topMargin: Style.space(3)
    width: Math.max(countText.implicitWidth + Style.space(6), Style.space(12))
    height: Style.space(12)
    radius: height / 2
    color: Color.accent

    Text {
      textFormat: Text.PlainText
      id: countText
      anchors.centerIn: parent
      // Past ninety-nine the number has stopped being information and the
      // badge is only saying "a lot", which it can say in three characters.
      text: root.unread > 99 ? "99+" : String(root.unread)
      font.family: root.fontFamily
      font.pixelSize: Math.max(8, Style.font.caption - Style.space(3))
      font.bold: true
      color: Color.background
    }
  }

  // ------------------------------------------------------------------- panel

  // Keep the controller alive; release only the view after close animations finish.
  property bool popupContentActive: false
  function preparePopup() {
    popupUnload.stop()
    popupContentActive = true
  }
  Connections {
    target: root
    function onOpenedChanged() {
      if (root.opened) root.preparePopup()
      else popupUnload.restart()
    }
  }
  Timer {
    id: popupUnload
    interval: 1000
    onTriggered: {
      if (!root.opened && !popup.visible) {
        root.popupContentActive = false
        root.rows = []
        root.expandedGroups = ({})
        root.cursorIndex = -1
        root.rowsDirty = true
      }
    }
  }
  NotificationPopup {
    id: popup
    objectName: "notificationCenterPopup"
    // Follow the bell on this output, using the normal edge clamping.
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.opened
    focusTarget: root.editingSettings ? settingsPane : keyCatcher
    padding: 0
    borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
    contentWidth: popup.fittedContentWidth(Style.space(root.panelWidth))
    // fittedContentHeight() clamps against availableCardHeight, which collapses
    // to its 120px minimum under a screen-sized bar window (see
    // usableCardHeight below), so the same fit is done here against the
    // corrected ceiling: the content plus the card insets, never taller than
    // the space the screen actually has.
    contentHeight: Math.round(Math.min(
      Math.max(popup.verticalContentInset, content.implicitHeight + Style.space(10) + popup.verticalContentInset),
      popup.usableCardHeight))

    Behavior on contentHeight {
      enabled: root.opened
      NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }

    // The stock omarchy bar window is only as tall as the bar strip, so the
    // screen minus that window is the space a panel has. Some bars draw their
    // strip inside a screen-sized window instead, which makes KeyboardPanel
    // mistake the whole screen for the bar and collapse to its 120px safety
    // minimum - a card a few entries tall no matter how much room there is.
    // Measure the strip itself when the window is screen-sized; both bars
    // expose barSize, so this works under either host.
    readonly property real usableCardHeight: {
      if (barH >= screenH && root.bar && Number(root.bar.barSize) > 0)
        return Math.max(120, screenH - (Number(root.bar.barSize) + gap + margin))
      return availableCardHeight
    }
    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      // While the search field has the focus it owns every key, including the
      // ones this would otherwise read as navigation.
      blocked: search.inputActiveFocus || root.editingSettings || moreMenu.visible
      onCloseRequested: root.searching ? root.endSearch() : root.close()
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: root.activateCursor(false)
      onDeleteRequested: root.activateCursor(true)
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        // "/" is the only key that starts a search, because a panel that
        // started filtering on any keypress would be a panel that swallows
        // whatever you were typing in the window underneath.
        if (text === "/") root.startSearch()
      }

      Column {
        id: content
        anchors.fill: parent
        spacing: Style.space(8)

        // -------------------------------------------------------- header

        Item {
          id: header
          visible: !root.editingSettings
          width: parent.width
          height: Style.space(58)

          Canvas {
            anchors.fill: parent
            property color surface: Color.popups.background
            property color accent: Color.accent
            // Inset the header curve so it meets the inside of the popup border.
            readonly property real cornerRadius: Math.max(0, Math.min(width / 2, height, popup.cornerRadius - Border.top(popup.borderSpec)))
            onCornerRadiusChanged: requestPaint()
            onSurfaceChanged: requestPaint()
            onAccentChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
              var ctx = getContext("2d")
              ctx.reset()
              var r = cornerRadius
              ctx.beginPath()
              ctx.moveTo(r, 0)
              ctx.lineTo(width - r, 0)
              ctx.arcTo(width, 0, width, r, r)
              ctx.lineTo(width, height)
              ctx.lineTo(0, height)
              ctx.lineTo(0, r)
              ctx.arcTo(0, 0, r, 0, r)
              ctx.closePath()
              var wash = ctx.createLinearGradient(0, 0, width, height)
              wash.addColorStop(0, Qt.tint(surface, Qt.alpha(accent, 0.12)))
              wash.addColorStop(1, Qt.tint(surface, Qt.alpha(accent, 0.035)))
              ctx.fillStyle = wash
              ctx.fill()
            }
          }
          Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Qt.alpha(root.foreground, 0.08)
          }

          Column {
            id: title
            anchors.left: parent.left
            anchors.leftMargin: Style.space(16)
            width: Math.max(0, silenceSwitch.x - x - Style.space(8))
            opacity: root.searching ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 100 } }
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)
            Text {
              textFormat: Text.PlainText
              width: parent.width
              elide: Text.ElideRight
              text: root.tr("Notifications")
              font.bold: true
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }
            Text {
              textFormat: Text.PlainText
              width: parent.width
              elide: Text.ElideRight
              text: {
                if (root.dnd) return root.tr("Do not disturb")
                var count = Model.unreadState(root.entries, root.readMark).unread
                return root.tr(count === 1 ? "1 unread" : "%1 unread", count)
              }
              color: Util.alpha(root.foreground, 0.6)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Row {
            id: actions
            anchors.right: parent.right
            anchors.rightMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            NotificationAction {
              objectName: "snoozedNotificationsButton"
              visible: root.hasSnoozes
              iconName: "snooze"
              foreground: Color.accent
              tooltipText: root.tr("Snoozed notifications")
              onClicked: {
                if (moreMenu.visible && moreMenu.page === "sources") moreMenu.close()
                else root.showOptions("sources")
              }
            }
            NotificationAction {
              objectName: "clearAllNotifications"
              iconName: "trash"
              tooltipText: root.tr("Clear all notifications")
              foreground: Qt.alpha(root.foreground, 0.65)
              hoverForeground: Color.urgent
              enabled: root.entries.length > 0
              onClicked: root.clearAll()
            }
            NotificationAction {
              id: moreButton
              objectName: "notificationMore"
              iconName: "more"
              tooltipText: root.tr("More options")
              foreground: Qt.alpha(root.foreground, 0.65)
              onClicked: moreMenu.visible ? moreMenu.close() : root.showOptions("main")
            }
          }

          ToggleSwitch {
            id: silenceSwitch
            objectName: "silenceNotificationsSwitch"
            anchors.right: searchControl.left
            anchors.rightMargin: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter
            trackHeight: Style.space(18)
            checked: root.dnd
            busy: !!root.store && root.store.dndBusy
            enabled: !!root.store
            foreground: root.foreground
            activeFocusOnTab: true
            hasCursor: activeFocus
            onToggled: if (enabled && !busy) root.toggleDnd()
            Accessible.role: Accessible.CheckBox
            Accessible.name: root.tr("Silence notifications")
            Accessible.checkable: true
            Accessible.checked: checked
            Accessible.onPressAction: if (enabled && !busy) root.toggleDnd()
            Keys.onReturnPressed: if (enabled && !busy) root.toggleDnd()
            Keys.onEnterPressed: if (enabled && !busy) root.toggleDnd()
            Keys.onSpacePressed: if (enabled && !busy) root.toggleDnd()

            PanelToolTip {
              visible: silenceSwitch.containsMouse
              text: root.dnd ? root.tr("Allow notifications") : root.tr("Silence notifications")
              fontFamily: root.fontFamily
            }
          }

          Controls.Popup {
            id: moreMenu
            objectName: "notificationOverflowMenu"
            popupType: Controls.Popup.Item
            property string page: "main"
            property string requestedPage: "main"
            x: Math.max(0, header.width - width - Style.space(12))
            y: header.height - Style.space(6)
            width: Math.min(Style.space(page === "sources" ? 220 : 280), header.width - Style.space(24))
            padding: Style.space(6)
            implicitHeight: optionsColumn.implicitHeight + padding * 2
            closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
            onAboutToShow: { page = requestedPage; requestedPage = "main" }
            onOpened: {
              if (page === "main") snoozeButton.forceActiveFocus()
              else if (page === "sources") resumeAllButton.forceActiveFocus()
            }
            onClosed: Qt.callLater(function() { if (root.opened && !root.editingSettings) moreButton.forceActiveFocus() })
            background: BorderSurface {
              color: Color.popups.background
              borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(1)))
              radius: Style.cornerRadius
            }
            enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Style.duration(80) } }
            exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Style.duration(60) } }
            contentItem: Column {
              id: optionsColumn
              spacing: Style.space(3)
              Button {
                width: parent.width
                visible: moreMenu.page === "snooze"
                text: "‹  Back"
                leftAlign: true
                focusable: true
                foreground: root.foreground
                onClicked: { moreMenu.page = "main"; snoozeButton.forceActiveFocus() }
              }
              Button {
                id: snoozeButton
                width: parent.width
                visible: moreMenu.page === "main"
                text: "Snooze notifications  ›"
                leftAlign: true
                focusable: true
                foreground: root.foreground
                onClicked: moreMenu.page = "snooze"
              }
              Button {
                width: parent.width
                visible: moreMenu.page === "main"
                text: root.tr("Settings")
                leftAlign: true
                focusable: true
                foreground: root.foreground
                onClicked: root.openSettings()
              }
              Repeater {
                model: moreMenu.page === "snooze" && root.service ? root.service.snoozeOptions : []
                delegate: Button {
                  required property var modelData
                  width: parent.width
                  text: modelData.menuLabel
                  leftAlign: true
                  focusable: true
                  foreground: root.foreground
                  onClicked: {
                    root.service.snoozeSource(root.service.globalKey, "Everything", modelData.seconds, true)
                    moreMenu.close()
                  }
                }
              }
              Text {
                visible: moreMenu.page === "sources"
                width: parent.width
                padding: Style.space(6)
                text: root.tr("Snoozed notifications")
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                color: Util.alpha(root.foreground, 0.65)
              }
              SnoozedSourceRow {
                width: parent.width
                visible: moreMenu.page === "sources" && root.service && root.service.globalSnoozeUntil > 0
                sourceKey: root.service ? root.service.globalKey : "*"
                sourceLabel: root.tr("Everything")
                snoozedUntil: root.service ? root.service.globalSnoozeUntil : 0
              }
              Repeater {
                model: {
                  if (moreMenu.page !== "sources" || !root.service) return []
                  root.service.snoozeRevision
                  return root.service.liveSnoozes()
                }
                delegate: SnoozedSourceRow {
                  required property var modelData
                  width: parent.width
                  sourceKey: modelData.key
                  sourceLabel: modelData.label
                  snoozedUntil: modelData.until
                }
              }
              Button {
                id: resumeAllButton
                width: parent.width
                visible: moreMenu.page === "sources" && root.hasSnoozes
                text: root.tr("Resume all")
                focusable: true
                fontSize: Style.font.caption
                verticalPadding: Style.space(4)
                foreground: Color.accent
                onClicked: { root.service.unsnoozeAll(); moreMenu.close() }
              }
            }
          }

          Rectangle {
            id: searchControl
            anchors.right: actions.left
            anchors.rightMargin: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter
            width: root.searching ? Math.max(Style.space(32), actions.x - silenceSwitch.width - Style.space(24)) : Style.space(32)
            height: Style.space(32)
            radius: Style.cornerRadius * 2
            color: root.searching ? Qt.alpha(root.foreground, 0.055) : "transparent"
            border.width: search.inputActiveFocus ? 1 : 0
            border.color: Color.accent
            // Clipping this rounded surface cuts off its antialiased focus outline.
            antialiasing: true
            border.pixelAligned: false
            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            NotificationAction {
              iconName: "search"
              tooltipText: root.tr("Search notifications  ( / )")
              foreground: root.searching ? Color.accent : Qt.alpha(root.foreground, 0.65)
              onClicked: root.startSearch()
            }
            SafeTextField {
              id: search
              objectName: "notificationSearch"
              x: Style.space(32)
              width: Math.max(0, parent.width - Style.space(64))
              height: parent.height
              visible: root.searching
              enabled: root.searching
              placeholderText: root.tr("Search")
              color: root.foreground
              placeholderTextColor: Qt.alpha(root.foreground, 0.45)
              selectionColor: Qt.alpha(Color.accent, 0.3)
              selectedTextColor: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              padding: 0
              background: Item {}
              onTextChanged: root.filter = text
              translate: root.tr
              onKeyPressed: function(event) {
                if (event.key === Qt.Key_Escape) { event.accepted = true; root.endSearch() }
                else if (event.key === Qt.Key_Down) {
                  event.accepted = true
                  keyCatcher.forceActiveFocus()
                  root.cursorIndex = -1
                  root.moveCursor(0, 1)
                }
              }
              // Keep the query while handing keyboard navigation to its results.
              onAccepted: {
                keyCatcher.forceActiveFocus()
                root.cursorIndex = -1
                root.moveCursor(0, 1)
              }
            }
            NotificationAction {
              anchors.right: parent.right
              visible: root.searching
              iconName: "close"
              tooltipText: root.tr("Close search  ( Esc )")
              foreground: Qt.alpha(root.foreground, 0.65)
              onClicked: root.endSearch()
            }
          }
        }

        Text {
          id: removalError
          x: Style.space(14)
          width: parent.width - Style.space(28)
          textFormat: Text.PlainText
          text: search.pasteError || (root.store ? root.tr(root.store.dndError || (root.store.focusError || root.store.loadError || root.store.removalError)) : "")
          visible: !root.editingSettings && text !== ""
          color: Color.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        // ---------------------------------------------------------- list

        Loader {
          id: listLoader
          width: parent.width
          active: true
          visible: !root.editingSettings && (root.rows.length > 0 || (item && item.contentHeight > 0))
          // Keep the lightweight list; detach its model to release delegates after fade-out.
          sourceComponent: Component {
            NotificationList {
              id: list
              width: parent.width
              // Construct only visible rows when restoring the detached model.
              cacheBuffer: 0
              wheelStep: Style.space(96)
              scrollbarWidth: Style.space(6)
              scrollbarInset: Style.space(2)
              // The flattened model keeps expanded stacks within the same virtualized list.
              readonly property int cap: root.listHeight > 0
                ? Math.min(Style.space(root.listHeight), root.listAvailableHeight) : root.listAvailableHeight

              implicitHeight: Math.min(Math.max(contentHeight, root.rows.length > 0 ? Style.space(100) : 0), cap)
              visible: root.rows.length > 0 || contentHeight > 0
              rows: root.rows
              contentActive: root.popupContentActive
              animateChanges: root.opened
              entranceDistance: Style.space(8)
              spacing: 0

              delegate: Item {
                id: delegateRoot
                required property string rowId
                // Qt can deliver removal after the source map has already advanced.
                // Copy only from the source map. A snapshot must not feed back
                // into the binding that reads it while a row is being removed.
                property var modelData: null
                readonly property var currentData: list.rowsById[rowId]
                onCurrentDataChanged: if (currentData && !retired) modelData = currentData
                Component.onCompleted: if (currentData) modelData = currentData
                required property int index
                property real entranceOffset: 0
                property bool retired: false
                enabled: !retired
                transform: Translate { y: delegateRoot.entranceOffset }
                ListView.delayRemove: root.popupContentActive && exitMotion.running
                ListView.onRemove: {
                  // An invisible window does not advance row exit animations.
                  if (!root.popupContentActive) return
                  // Freeze departing content until Qt finishes its removal transition.
                  retired = true
                  exitMotion.start()
                }
                SequentialAnimation {
                  id: exitMotion
                  NumberAnimation { target: delegateRoot; property: "opacity"; to: 0; duration: 120; easing.type: Easing.OutCubic }
                  // Let ListView lay out the shrinking space, including its scroll extent.
                  NumberAnimation { target: delegateRoot; property: "height"; to: 0; duration: 140; easing.type: Easing.OutCubic }
                }
                width: list.width
                height: rowLoader.implicitHeight

                Loader {
                  id: rowLoader
                  // ListView positions delegates; inset their content instead of the delegate itself.
                  x: Style.space(14)
                  width: parent.width - Style.space(28)
                  active: !!delegateRoot.modelData
                  sourceComponent: delegateRoot.modelData && delegateRoot.modelData.kind === "header" ? headerDelegate : messageDelegate
                }
                Component {
                  id: headerDelegate
                  NotificationStackHeader {
                    compact: root.compact
                    group: delegateRoot.modelData.group
                    expanded: delegateRoot.modelData.expanded
                    language: root.language
                    now: root.now
                    readMark: root.readMark
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    hasCursor: root.keyboardNavigation && root.cursorIndex === delegateRoot.index
                    dismissHasCursor: hasCursor && root.cursorDismiss
                    onPointerUsed: root.keyboardNavigation = false
                    onToggleRequested: root.toggleGroup(group.key)
                    onRemoveRequested: root.removeGroup(group)
                  }
                }
                Component {
                  id: messageDelegate
                  NotificationRow {
                    compact: root.compact
                    entry: delegateRoot.modelData.entry
                    first: delegateRoot.modelData.first
                    last: delegateRoot.modelData.last
                    layered: delegateRoot.modelData.layered
                    expanded: delegateRoot.modelData.expanded
                    groupCritical: delegateRoot.modelData.group.critical
                    language: root.language
                    now: root.now
                    showBody: root.showBody
                    showPreview: root.showPreview
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    hasCursor: root.keyboardNavigation && root.cursorIndex === delegateRoot.index
                    dismissHasCursor: hasCursor && root.cursorDismiss
                    onPointerUsed: root.keyboardNavigation = false
                    onClicked: root.activate(entry)
                    onRemoveRequested: root.remove(entry.key)
                  }
                }
              }
            }
          }
        }

        // --------------------------------------------------------- empty

        Text {
          textFormat: Text.PlainText
          x: Style.space(14)
          width: parent.width - Style.space(28)
          visible: !root.editingSettings && root.rows.length === 0 && (!list || list.contentHeight <= 0)
          horizontalAlignment: Text.AlignHCenter
          topPadding: Style.space(22)
          bottomPadding: Style.space(22)
          text: !root.loaded ? root.tr("Reading the archive…")
              : root.filter !== "" ? root.tr("Nothing matches “%1”", root.filter)
              : root.tr("Nothing has come in yet")
          wrapMode: Text.WordWrap
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          color: root.foreground
          opacity: 0.55
        }

        SettingsPane {
          id: settingsPane
          objectName: "notificationSettingsPane"
          width: parent.width
          height: Math.min(implicitHeight, Math.max(Style.space(100), popup.usableCardHeight - popup.verticalContentInset - Style.space(10)))
          visible: root.editingSettings
          settings: root.settings
          popupSettings: root.popupSettings
          popupInstalled: root.popupPluginInstalled
          popupAvailable: root.popupPluginInstalled && root.popupSettingsAvailable
          loading: root.popupSettingsLoading
          saving: root.preferenceActive !== null
          error: root.settingsError
          language: root.language
          onSave: function(scope, key, value) { root.savePreference(scope, key, value) }
          onBack: root.closeSettings()
          onClearError: root.settingsError = ""
          onPasteFailed: function(message) { root.settingsError = message }
        }

      }
    }
  }

}

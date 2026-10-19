import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Ui
import "MenuModel.js" as MenuModel
import "PluginRows.js" as PluginRows
import "../bar/widgets/TrayModel.js" as TrayModel

Item {
  id: root

  // Injected by strata-shell when this plugin is summoned.
  property string strataPath: Quickshell.env("STRATA_PATH")
  property var shell: null
  property var manifest: null
  onShellChanged: if (root.rowsLoaded) {
    root.refreshPluginProviders()
    if (root.opened) root.rebuildDisplay(true)
  }

  // Plugin lifecycle hooks. The host calls open(payloadJson) after
  // `strata-shell shell summon strata.menu ...` and close() when hidden.
  property string pendingInitialMenu: "root"

  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) { payload = ({}) }

    if (payload.fontFamily) root.fontFamily = payload.fontFamily

    if (payload.mode === "app-actions") {
      root.openAppActions(payload)
    } else if (payload.mode === "select" || payload.mode === "input") {
      root.openDmenu(payload)
    } else {
      root.openRoute(payload.initialMenu || payload.menu || "root")
    }
  }

  function close() {
    root.cancel()
  }

  function refresh() {
    defaultMenuFile.reload()
    userMenuFile.reload()
    return "ok"
  }

  function ping() { return "ok" }

  property string fontFamily: Style.font.menuFamily
  // JSONC menu definitions. The shell parses both at startup and merges
  // the user file on top of the defaults, so the keybind → IPC → visible
  // path doesn't have to shell out to bash + jq on every open.
  property string defaultMenuPath: strataPath + "/default/strata/strata-menu.jsonc"
  property string userMenuPath: Quickshell.env("HOME") + "/.config/strata/extensions/strata-menu.jsonc"
  property var defaultMenuItems: []
  property var userMenuItems: []
  property bool opened: false
  property string mode: "menu"
  readonly property bool dmenuActive: mode === "select" || mode === "input"
  property string dmenuPrompt: ""
  property var dmenuOptions: []
  property string dmenuDescription: ""
  readonly property bool hasDmenuDescription: root.dmenuActive && root.mode === "select" && root.dmenuDescription !== ""
  readonly property int dmenuDescriptionHeight: hasDmenuDescription ? Math.ceil(Math.min(descriptionText.implicitHeight, panel.height * 0.3)) : 0
  readonly property int dmenuDescriptionInset: hasDmenuDescription ? dmenuDescriptionHeight + root.contentSpacing : 0
  property string selectionFile: ""
  property string doneFile: ""
  property int dmenuWidth: 300
  property int dmenuMaxHeight: 0
  property bool requestActive: false
  property bool rowsLoaded: false
  property string activeMenu: "root"
  property string filterText: ""
  property int selectedIndex: 0
  property bool cursorActive: false
  property int requestSerial: 0
  property int applySerial: 0
  property var items: ({})
  property var itemOrder: []
  property var navStack: []
  property var providersLoaded: ({})
  property var providerQueue: []
  property int providerRevision: 0
  property var windowClients: []
  property var fileResults: []
  property string clipboardHistoryRaw: "[]"
  property var usageState: ({ entries: ({}) })
  property var appActions: []
  property var trayKnownItems: ({})
  property int appActionsPid: 0
  readonly property bool appActionsMode: mode === "app-actions"
  readonly property string trayStateSignature: {
    var values = SystemTray.items.values
    var snapshot = []
    for (var i = 0; i < values.length; i++) {
      var trayItem = values[i]
      snapshot.push([trayItem.id, trayItem.title, trayItem.tooltipTitle, trayItem.icon, trayItem.status])
    }
    return JSON.stringify([snapshot, root.trayEntry()])
  }
  onTrayStateSignatureChanged: root.refreshTrayProviders()

  // Shared application engine (entries, hidden filters, icons, launch,
  // removal), owned by the shell and also used by the standalone launcher.
  readonly property var appLibrary: root.shell ? root.shell.appLibrary : null
  property bool deleteConfirmOpen: false
  property var deleteTarget: null
  property string pluginError: ""
  onOpenedChanged: {
    if (!opened) { deleteConfirmOpen = false; deleteTarget = null }
    else pluginError = ""
  }
  onActiveMenuChanged: pluginError = ""
  // Bound to the central [menu] section in shell.toml via Color.qml.
  // Each color already includes its alpha companion (composed in the
  // singleton), so consumers can drop them straight into a Rectangle.
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  property color selectedBorder: Color.menu.selectedBorder
  property var selectedBorderSpec: Border.surfaceSpec("menu", "selected-border", selectedBorder, 0)
  readonly property real rowReservedBorderLeft: Border.left(selectedBorderSpec)
  readonly property real rowReservedBorderRight: Border.right(selectedBorderSpec)
  readonly property int cornerRadius: Style.cornerRadius
  property int contentMargin: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(48), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int contentSpacing: Style.spacing.md
  property int footerHeight: Style.space(22)
  property int baseRowHeight: Math.max(Style.space(50), Style.font.body + Style.spacing.rowPaddingX * 2)
  property int detailRowHeight: Math.max(Style.space(58), Style.font.body + Style.font.caption + Style.spacing.rowPaddingX * 2)
  // How much of the first hidden row stays visible at the fold — enough to
  // read as a cut-off row rather than a bottom border.
  property int rowPeek: Math.round(baseRowHeight * 0.55)
  property int rowSpacing: Style.spacing.xs
  property int dividerHeight: Style.space(17)
  property int sectionHeight: Style.space(26)
  property bool searchDivider: false
  property int layoutSerial: 0
  property int cardWidth: Math.min(root.dmenuActive ? Style.space(root.dmenuWidth) : Style.space(560), panel.width - Style.gapsOut * 2)
  property int visibleRowsHeight: root.dmenuActive ? dmenuRowListHeight(layoutSerial, displayModel.count, filterText) : rowListHeight(layoutSerial, displayModel.count, filterText, searchDivider)
  property int cardHeight: root.dmenuActive
    ? Math.min(contentMargin * 2 + headerHeight + dmenuDescriptionInset + (mode === "input" ? 0 : contentSpacing + visibleRowsHeight), panel.height - Style.gapsOut * 2)
    : Math.min(contentMargin * 2 + headerHeight + contentSpacing + visibleRowsHeight + contentSpacing + footerHeight, panel.height - Style.gapsOut * 2)

  function finishRequest(selection) {
    if (!root.requestActive || !root.doneFile) {
      root.opened = false
      return
    }

    var activeSelectionFile = root.selectionFile
    var activeDoneFile = root.doneFile
    root.requestActive = false
    root.selectionFile = ""
    root.doneFile = ""

    if (selection === null || selection === undefined) {
      resultProc.command = ["bash", "-c", ": > " + Util.shellQuote(activeDoneFile)]
    } else {
      resultProc.command = ["bash", "-c", "printf '%s\\n' " + Util.shellQuote(selection) + " > " + Util.shellQuote(activeSelectionFile) + "; : > " + Util.shellQuote(activeDoneFile)]
    }
    resultProc.running = true
  }

  function runAction(action) {
    var command = String(action || "")
    if (!command) return

    var launch = MenuModel.pluginAction(command)
    if (launch && root.shell) {
      var handled = launch.method === "toggle"
        ? root.shell.toggle(launch.id, launch.payload)
        : root.shell.summon(launch.id, launch.payload)
      if (handled) return
    }

    Util.execDetached(command)
  }

  function loadUsage(raw) {
    var parsed = ({})
    try { parsed = JSON.parse(String(raw || "{}")) } catch (e) { }
    root.usageState = {
      entries: parsed.entries && typeof parsed.entries === "object" && !Array.isArray(parsed.entries) ? parsed.entries : ({})
    }
    if (root.opened && !root.filterText && root.activeMenu === "root") root.rebuildDisplay()
  }

  function saveUsage() {
    usageFile.setText(JSON.stringify(root.usageState) + "\n")
  }

  function recordUsage(itemId) {
    if (!itemId || itemId.indexOf("search.") === 0 || itemId.indexOf("app-action.") === 0) return
    var entries = ({})
    var source = root.usageState.entries || ({})
    for (var id in source) entries[id] = source[id]
    var previous = source[itemId] || ({})
    entries[itemId] = { count: Math.min(9999, Number(previous.count || 0) + 1), last: Date.now() }
    root.usageState = { entries: entries }
    root.saveUsage()
  }

  function usageBonus(itemId) {
    var source = root.usageState.entries || ({})
    var used = source[itemId] || ({})
    var count = Math.max(0, Number(used.count || 0))
    return Math.min(count, 30) * 8
  }

  // Menu rows only surface their detail while a search is narrowing them;
  // dmenu rows carry caller-supplied subtext that must always be visible.
  function rowHeightForDetail(detail, kind) {
    return (root.filterText || root.dmenuActive || root.appActionsMode || kind === "tray-toggle" || kind === "plugin-toggle") && detail ? root.detailRowHeight : root.baseRowHeight
  }

  // Height the card can devote to rows before running off the screen — or
  // past the frozen top edge once a search has pinned the card in place.
  // Uses panel.cardTop rather than effectiveCardTop: the centered top is
  // derived from the card height, which this value feeds.
  function availableRowsHeight() {
    var top = panel.cardTop >= 0 ? panel.cardTop : Style.gapsOut
    var available = panel.height - top - Style.gapsOut - root.contentMargin * 2 - root.headerHeight - root.contentSpacing
      - root.dmenuDescriptionInset
      - (root.dmenuActive ? 0 : root.footerHeight + root.contentSpacing)
    // The starting menu sets the ceiling along with the offset: drilling into
    // a longer submenu scrolls behind the fold instead of growing the card.
    if (panel.maxRowsHeight >= 0) available = Math.min(available, panel.maxRowsHeight)
    // A card that swallows the whole screen reads as a page, not a menu.
    return Math.min(available, Math.round(panel.height * 0.7))
  }

  // When every row fits, the list gets its full height. When they don't,
  // the card must end mid-row: a clipped row is what tells the eye there is
  // more below the fold, so never come out even on a row boundary.
  function foldedListHeight(totals, available) {
    var count = totals.length
    if (count === 0) return root.baseRowHeight
    if (totals[count - 1] <= available) return totals[count - 1]

    var peek = root.rowPeek
    var full = 0
    while (full < count && totals[full] <= available) full++
    while (full > 1 && totals[full - 1] + root.rowSpacing + peek > available) full--
    if (full < 1) return Math.max(available, root.baseRowHeight)

    return totals[full - 1] + root.rowSpacing + peek
  }

  function rowListHeight(_serial, _count, _filter, _divider) {
    if (displayModel.count === 0) return root.baseRowHeight

    var totals = []
    var total = 0
    var previousSection = ""

    for (var i = 0; i < displayModel.count; i++) {
      var row = displayModel.get(i)
      if (i > 0) total += root.rowSpacing
      if (row.section && row.section !== previousSection)
        total += row.section === "drilldown" ? root.dividerHeight : root.sectionHeight
      total += root.rowHeightForDetail(row.detail, row.kind)
      previousSection = row.section
      totals.push(total)
    }

    return foldedListHeight(totals, availableRowsHeight())
  }

  function dmenuRowListHeight(_serial, _count, _filter) {
    if (root.mode === "input") return 0
    if (displayModel.count === 0) return root.baseRowHeight

    var available = availableRowsHeight()
    if (root.dmenuMaxHeight > 0) available = Math.min(available, Style.space(root.dmenuMaxHeight))

    var totals = []
    var total = 0
    for (var i = 0; i < displayModel.count; i++) {
      if (i > 0) total += root.rowSpacing
      total += root.rowHeightForDetail(displayModel.get(i).detail)
      totals.push(total)
    }

    return foldedListHeight(totals, available)
  }

  function item(id) {
    return root.items[id] || null
  }

  // ------------------------------------------------------------------
  // JSONC → normalized item array. Mirrors the bash bin's jq pipeline so
  // the on-disk authoring format stays untouched.
  // ------------------------------------------------------------------

  function stripJsonc(raw) {
    return MenuModel.stripJsonc(raw)
  }

  function normalizeAliases(value) {
    return MenuModel.normalizeAliases(value)
  }

  function normalizeItem(id, raw) {
    return MenuModel.normalizeItem(id, raw)
  }

  function parseMenuJsonc(raw) {
    return MenuModel.parseMenuJsonc(raw)
  }

  // Merge defaults + user extension. Later entries override earlier ones
  // on a per-key basis (so the user can tweak label/icon/action without
  // re-declaring the whole row).
  function rebuildItemsFromSources() {
    var mergedMenu = MenuModel.mergeMenuSources(root.defaultMenuItems, root.userMenuItems)
    root.providerRevision += 1
    root.providersLoaded = ({})
    root.providerQueue = []
    root.items = mergedMenu.items
    root.itemOrder = mergedMenu.itemOrder
    root.rowsLoaded = true
    root.mergePluginLaunchRows()
    root.evaluateGuards()
    if (root.opened) {
      root.rebuildDisplay()
      if (!root.dmenuActive) {
        if (root.filterText.trim()) root.loadProvidersForSearch()
        else root.loadProviderForMenu(root.activeMenu)
      }
    }
  }

  // Each known provider is a tiny bash one-liner that enumerates a list and
  // emits one tab-delimited row per item: `label\tvalue\tcurrent`. The shell
  // turns those into menu items children of `menuId`. A `volatile` provider
  // re-runs every time its submenu is entered, so a font installed since the
  // shell started shows up without restarting it.
  readonly property var providers: ({
    "fonts": {
      script: "current=$(strata-font-current 2>/dev/null); strata-font-list 2>/dev/null | while read -r f; do [[ -z $f ]] && continue; printf '%s\\t%s\\t%s\\n' \"$f\" \"$f\" \"$current\"; done",
      icon: "",
      volatile: true,
      actionFor: function(value) { return "strata-font-set " + Util.shellQuote(value) }
    },
    "power-profiles": {
      script: "current=$(powerprofilesctl get 2>/dev/null); strata-powerprofiles-list 2>/dev/null | while read -r p; do [[ -z $p ]] && continue; printf '%s\\t%s\\t%s\\n' \"$p\" \"$p\" \"$current\"; done",
      icon: "\udb81\udc0b",
      actionFor: function(value) { return "strata-powerprofiles-set autodetect " + Util.shellQuote(value) }
    }
  })

  function slugify(value) {
    return MenuModel.slugify(value)
  }

  // The apps provider is QML-native: rows come from the shared AppLibrary
  // (DesktopEntries) instead of a bash enumeration, so they carry image
  // icons, launch feedback, and uninstall support like the launcher.
  function mergeAppRows() {
    if (!root.appLibrary) return

    var rows = root.appLibrary.sortedEntries("")
    var appRows = []
    for (var j = 0; j < rows.length; j++) {
      var entry = rows[j].entry
      var appId = String(entry.id || "")
      if (!appId) continue
      var subtext = root.appLibrary.entrySubtext(entry)
      var aliases = subtext ? [subtext] : []
      try {
        if (entry.keywords && typeof entry.keywords.join === "function") aliases = aliases.concat(entry.keywords)
      } catch (e) { }
      appRows.push({
        id: "apps." + appId,
        parent: "apps",
        kind: "app",
        icon: "",
        appIcon: String(entry.icon || ""),
        appId: appId,
        label: root.appLibrary.entryName(entry),
        title: "",
        target: "",
        description: subtext,
        action: "",
        provider: "",
        aliases: aliases,
        when: "",
        checked: "",
        disabled: "",
        order: 0
      })
    }

    var merged = MenuModel.mergeAppRows(root.items, root.itemOrder, appRows)
    root.items = merged.items
    root.itemOrder = merged.itemOrder
    if (root.opened) root.rebuildDisplay()
  }

  function castEntry() {
    var config = root.shell ? root.shell.shellConfig : null
    var layout = config && config.bar ? config.bar.layout : null
    for (var section of ["left", "center", "right"]) {
      var entries = layout && Array.isArray(layout[section]) ? layout[section] : []
      for (var entry of entries) if (entry && entry.id === "strata.cast") return entry
    }
    return null
  }
  readonly property bool castingEnabled: !!castEntry() && castEntry().discoveryEnabled === true
  property bool shortcutGuideEnabled: true
  property bool osdEnabled: true
  FileView {
    path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/strata/osd.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try { root.osdEnabled = JSON.parse(text()).enabled !== false } catch (error) {}
    }
    onLoadFailed: root.osdEnabled = true
  }
  FileView {
    path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/strata/shortcut-guide.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try { root.shortcutGuideEnabled = JSON.parse(text()).enabled !== false } catch (error) {}
    }
    onLoadFailed: root.shortcutGuideEnabled = true
  }
  function toggleShortcutGuide() {
    root.disarmPointer()
    Quickshell.execDetached(["strata-shortcut-guide", "toggle"])
  }
  function promoteShortcut(selection) {
    if (root.shortcutGuideEnabled)
      Quickshell.execDetached(["strata-shell", "shortcut-guide", "promote", JSON.stringify(selection)])
  }
  function toggleCasting() {
    var entry = root.castEntry()
    root.disarmPointer()
    if (entry && root.shell) {
      var next = Object.assign({}, entry, { discoveryEnabled: !root.castingEnabled })
      root.shell.updateEntryInline("strata.cast", next)
    } else Quickshell.execDetached(["strata-toggle-cast"])
  }

  function trayEntry() {
    var config = root.shell ? root.shell.shellConfig : null
    var layout = config && config.bar ? config.bar.layout : null
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var entries = layout ? layout[sections[s]] : []
      if (!Array.isArray(entries)) continue
      for (var i = 0; i < entries.length; i++)
        if (entries[i] && entries[i].id === "strata.tray") return entries[i]
    }
    return null
  }

  function refreshPluginProviders() {
    root.mergePluginLaunchRows()
    for (var i = 0; i < root.itemOrder.length; i++) {
      var entry = root.item(root.itemOrder[i])
      if (entry && entry.provider === "plugins" && root.providersLoaded[entry.id]) root.mergePluginRows(entry.id)
    }
  }

  function mergePluginLaunchRows() {
    if (!root.shell || !root.shell.pluginRegistry) return
    var registry = root.shell.pluginRegistry
    var rows = PluginRows.launchRows(registry.installedPlugins, registry)
    var merged = MenuModel.swapProviderRows(root.items, root.itemOrder, "@plugin-launches", rows)
    root.items = merged.items
    root.itemOrder = merged.itemOrder
  }

  function mergePluginRows(menuId) {
    if (!root.shell || !root.shell.pluginRegistry) return
    var registry = root.shell.pluginRegistry
    var rows = PluginRows.rows(registry.installedPlugins, registry, menuId)
    var merged = MenuModel.swapProviderRows(root.items, root.itemOrder, menuId, rows)
    root.items = merged.items
    root.itemOrder = merged.itemOrder
    if (root.opened && !root.dmenuActive && !root.appActionsMode) root.rebuildDisplay(true)
  }

  function togglePlugin(row) {
    if (!root.shell || !root.shell.pluginRegistry || pluginRemoval.running) return
    root.pluginError = ""
    root.disarmPointer()
    if (row.appId === "strata.menu" && row.action === "on") {
      root.deleteTarget = {kind:"plugin", appId:row.appId, label:row.label, mode:"disable"}
      deleteConfirm.selectedIndex = 0
      root.deleteConfirmOpen = true
      return
    }
    if (!root.shell.pluginRegistry.setEnabled(row.appId, row.action !== "on"))
      root.pluginError = root.shell.pluginRegistry.lastEnableError || "Could not change plugin state."
  }

  function refreshTrayProviders() {
    var menus = []
    for (var i = 0; i < root.itemOrder.length; i++) {
      var entry = root.item(root.itemOrder[i])
      if (entry && entry.provider === "tray-icons" && root.providersLoaded[entry.id]) menus.push(entry.id)
    }
    for (var j = 0; j < menus.length; j++) root.mergeTrayRows(menus[j])
  }

  function mergeTrayRows(menuId) {
    var config = root.trayEntry()
    var hidden = config && Array.isArray(config.hidden) ? config.hidden : []
    var pinned = config && Array.isArray(config.pinned) ? config.pinned : []
    var known = JSON.parse(JSON.stringify(root.trayKnownItems))
    var live = ({})
    var values = SystemTray.items.values
    for (var i = 0; i < values.length; i++) {
      var trayItem = values[i]
      var id = String(trayItem.id || "")
      if (!id || TrayModel.ownedByStrata(trayItem, null)) continue
      var label = String(trayItem.title || trayItem.tooltipTitle || id)
      known[id] = label
      live[id] = { icon: String(trayItem.icon || ""), active: trayItem.status !== Status.Passive }
    }
    var savedIds = hidden.concat(pinned)
    for (var j = 0; j < savedIds.length; j++) {
      var savedId = String(savedIds[j])
      if (known[savedId] === undefined) known[savedId] = savedId
    }
    // Keep encountered apps in this session, including an offline item just
    // switched on, so toggling it does not move the next item under the cursor.
    root.trayKnownItems = known
    var ids = Object.keys(known).sort(function(a, b) { return known[a].localeCompare(known[b]) })
    var rows = []
    for (var k = 0; k < ids.length; k++) {
      var itemId = ids[k]
      var shown = hidden.indexOf(itemId) < 0
      var detail = !shown ? "Hidden" : pinned.indexOf(itemId) >= 0 ? "Pinned to bar" : "In tray drawer"
      if (!live[itemId] || !live[itemId].active) detail += " · app inactive"
      rows.push({ id: menuId + "." + encodeURIComponent(itemId).replace(/\./g, "%2E"), parent: menuId,
        kind: "tray-toggle", icon: "󰐊", iconFont: "", appIcon: "", appId: itemId,
        label: known[itemId], title: "", target: "", description: detail,
        action: shown ? "on" : "off", provider: "", aliases: [itemId, "tray"], when: "", checked: "", disabled: "", order: k })
    }
    var merged = MenuModel.swapProviderRows(root.items, root.itemOrder, menuId, rows)
    root.items = merged.items
    root.itemOrder = merged.itemOrder
    if (root.opened && !root.dmenuActive && !root.appActionsMode) root.rebuildDisplay()
  }

  function toggleTrayVisibility(id) {
    var entry = root.trayEntry()
    if (!entry || !id || !root.shell || typeof root.shell.updateEntryInline !== "function") return
    var next = JSON.parse(JSON.stringify(entry))
    var hidden = Array.isArray(next.hidden) ? next.hidden.slice() : []
    var index = hidden.indexOf(id)
    if (index >= 0) hidden.splice(index, 1)
    else hidden.push(id)
    next.hidden = hidden
    root.disarmPointer()
    root.shell.updateEntryInline("strata.tray", next)
  }

  function startProviderForMenu(id) {
    var entry = root.item(id)
    if (!entry || !entry.provider || root.providersLoaded[id]) return
    if (entry.provider === "apps") {
      root.providersLoaded[id] = true
      root.mergeAppRows()
      return
    }
    if (entry.provider === "tray-icons") {
      root.providersLoaded[id] = true
      root.mergeTrayRows(id)
      return
    }
    if (entry.provider === "plugins") {
      root.providersLoaded[id] = true
      root.mergePluginRows(id)
      return
    }
    var spec = root.providers[entry.provider]
    if (!spec) return

    root.providersLoaded[id] = true
    providerProc.menuId = id
    providerProc.providerKey = entry.provider
    providerProc.revision = root.providerRevision
    providerProc.collected = ""
    providerProc.command = ["bash", "-lc", spec.script]
    providerProc.running = true
  }

  function mergeProviderRows(rows, menuId, providerKey) {
    var spec = root.providers[providerKey]
    if (!spec) return
    var lines = String(rows || "").split("\n")
    var providerRows = []
    var takenIds = ({})
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line) continue
      var parts = line.split("\t")
      var label = parts[0] || ""
      var value = parts[1] || parts[0] || ""
      var current = parts[2] || ""
      if (!label) continue
      // Distinct values can slugify alike — Fira Code and Fira-Code both give
      // fira-code — and a repeated id is dropped, which would silently lose a
      // row from the list. Nudge it until it is the row's own.
      var rowId = menuId + "." + root.slugify(value)
      while (takenIds[rowId]) rowId += "-"
      takenIds[rowId] = true

      providerRows.push({
        id: rowId,
        parent: menuId,
        kind: "action",
        icon: (value === current) ? "✓" : (spec.icon || ""),
        label: label,
        title: "",
        target: "",
        description: "",
        action: spec.actionFor(value),
        provider: "",
        aliases: [],
        when: "",
        checked: "",
        disabled: "",
        order: 0
      })
    }
    var merged = MenuModel.swapProviderRows(root.items, root.itemOrder, menuId, providerRows)
    root.items = merged.items
    root.itemOrder = merged.itemOrder
    if (root.opened) root.rebuildDisplay()
  }

  function startNextProvider() {
    if (providerProc.running) return

    while (root.providerQueue.length > 0) {
      var id = root.providerQueue.shift()
      var entry = root.item(id)
      if (!entry || !entry.provider || root.providersLoaded[id]) continue

      root.startProviderForMenu(id)
      return
    }
  }

  // Entering a submenu is the one moment a volatile list is worth paying for
  // again: it may have been reshaped by the last pick from it. Search doesn't
  // invalidate, or every keystroke would restart the same enumeration.
  function invalidateVolatileProvider(id) {
    var entry = root.item(id)
    var spec = entry && entry.provider ? root.providers[entry.provider] : null
    if ((spec && spec.volatile) || (entry && (entry.provider === "tray-icons" || entry.provider === "plugins"))) root.providersLoaded[id] = false
  }

  function loadProviderForMenu(id) {
    var entry = root.item(id)
    if (!entry || !entry.provider || root.providersLoaded[id]) return

    // Native providers don't touch providerProc, so they never need to queue.
    if (entry.provider === "apps" || entry.provider === "tray-icons" || entry.provider === "plugins") {
      root.startProviderForMenu(id)
      return
    }

    if (providerProc.running) {
      if (root.providerQueue.indexOf(id) < 0) root.providerQueue = root.providerQueue.concat([id])
      return
    }

    root.startProviderForMenu(id)
  }

  function loadProvidersForSearch() {
    var active = root.item(root.activeMenu) ? root.activeMenu : "root"

    for (var i = 0; i < root.itemOrder.length; i++) {
      var entry = root.item(root.itemOrder[i])
      if (!entry || !entry.provider || root.providersLoaded[entry.id]) continue
      if (active !== "root" && entry.id !== active && !root.isDescendantOf(entry.id, active)) continue

      root.loadProviderForMenu(entry.id)
    }
  }

  function depthFor(id) {
    return MenuModel.depthFor(root.items, id)
  }

  function pathFor(id) {
    return MenuModel.pathFor(root.items, id)
  }

  function parentPathFor(id) {
    return MenuModel.parentPathFor(root.items, id)
  }

  function isDescendantOf(id, ancestorId) {
    return MenuModel.isDescendantOf(root.items, id, ancestorId)
  }

  function childCount(id) {
    return MenuModel.childCount(root.items, root.itemOrder, id)
  }

  // Guarded items are hidden when their `when:` evaluates false. Static
  // submenus are also hidden when none of their descendants are visible;
  // provider-backed menus stay visible because their rows load on demand.
  function isVisible(entry) {
    return MenuModel.isVisible(root.items, root.itemOrder, root.whenResults, entry, 0, function(id) {
      var registry = root.shell ? root.shell.pluginRegistry : null
      if (!registry) return false
      var enabledId = typeof registry.resolveEnabledId === "function" ? registry.resolveEnabledId(id) : id
      return !!enabledId && registry.isEnabled(enabledId)
    })
  }

  // Label with the ✓ marker baked in when `checked:` or `disabled:` evaluated
  // truthy.
  function labelFor(entry) {
    return MenuModel.labelFor(entry, root.checkedResults, root.disabledResults)
  }

  function searchableToken(value) {
    return MenuModel.searchableToken(value)
  }

  function leafIdFor(id) {
    return MenuModel.leafIdFor(id)
  }

  function nameSearchText(entry) {
    return MenuModel.nameSearchText(entry)
  }

  function termInSearchWords(term, text) {
    return MenuModel.termInSearchWords(term, text)
  }

  function descriptionTextMatches(query, text) {
    return MenuModel.descriptionTextMatches(query, text)
  }

  // Rows whose `disabled:` evaluated truthy stay listed but dimmed, and the
  // cursor steps over them.
  function isDisabled(entry) {
    return MenuModel.isDisabled(root.disabledResults, entry)
  }

  // A disabled row earns its place in the submenu it belongs to, where the
  // list around it is the point. Search is a list of what you can do, so it
  // leaves them out.
  function matchesQuery(entry, query) {
    if (entry && entry.kind === "plugin-toggle" && root.activeMenu !== entry.parent) return false
    return MenuModel.matchesQuery(entry, query, root.isVisible(entry) && !root.isDisabled(entry))
  }

  function searchScore(entry, query) {
    return MenuModel.searchScore(root.items, entry, query)
  }

  function displayRow(entry, detail, score, section) {
    return MenuModel.displayRow(root.items, root.itemOrder, root.checkedResults, root.disabledResults, entry, detail, score, section)
  }

  function rowSelectable(index) {
    if (index < 0 || index >= displayModel.count) return false
    return !displayModel.get(index).disabled
  }

  // First selectable row at or past `from`, continuing in the direction of
  // travel and wrapping. -1 when every row is disabled, which leaves the menu
  // with no cursor at all rather than one parked on a row Enter won't run.
  function nextSelectable(from, direction) {
    var count = displayModel.count
    if (count === 0) return -1

    var step = direction < 0 ? -1 : 1
    var index = ((from % count) + count) % count
    for (var i = 0; i < count; i++) {
      if (root.rowSelectable(index)) return index
      index = (index + step + count) % count
    }

    return -1
  }

  // Park the cursor on a selectable row after the rows underneath it changed.
  // A menu with nothing selectable in it -- every app in it already installed
  // -- shows no cursor at all, and grows one the moment a row can take it.
  function settleCursor() {
    var target = root.nextSelectable(root.selectedIndex, 1)
    root.selectedIndex = target >= 0 ? target : 0
    root.cursorActive = target >= 0
  }

  function rebuildDmenuDisplay() {
    root.searchDivider = false

    if (root.mode === "input") {
      MenuModel.syncDisplayRows(displayModel, [])
      layoutSerial += 1
      return
    }

    var rows = []
    var query = root.filterText.trim().toLowerCase()
    for (var i = 0; i < root.dmenuOptions.length; i++) {
      // An option is "<label>", "<glyph>\t<label>", or
      // "<glyph>\t<label>\t<subtext>". The glyph never comes back with the
      // selection; the subtext renders under the label, filters alongside it,
      // and returns with the selection as a stable key for same-named rows.
      var parts = String(root.dmenuOptions[i] || "").split("\t")
      var icon = parts.length > 1 ? parts.shift() : ""
      var label = parts.shift() || ""
      var detail = parts.join("\t")
      if (query && label.toLowerCase().indexOf(query) < 0
          && detail.toLowerCase().indexOf(query) < 0) continue
      rows.push({
        itemId: "dmenu." + i,
        disabled: false,
        kind: "dmenu",
        icon: icon,
        iconFont: "",
        appIcon: "",
        appId: "",
        label: label,
        target: "",
        detail: detail,
        path: "",
        childCount: 0,
        action: "",
        provider: "",
        score: i,
        section: ""
      })
    }

    MenuModel.syncDisplayRows(displayModel, rows)
    layoutSerial += 1

    if (displayModel.count === 0) selectedIndex = 0
    else if (selectedIndex >= displayModel.count) selectedIndex = displayModel.count - 1
    else if (selectedIndex < 0) selectedIndex = 0

    Qt.callLater(function() {
      if (displayModel.count > 0) root.revealCursor()
    })
  }

  function applyDisplayRows(rows, preserveView) {
    var selected = displayModel.count > root.selectedIndex ? displayModel.get(root.selectedIndex) : null
    var selectedId = selected ? selected.itemId : ""
    var selectedSection = selected ? selected.section : ""
    var result = MenuModel.syncDisplayRows(displayModel, rows)
    if (preserveView && !result.changed) return
    if (!preserveView || result.structural) layoutSerial += 1
    if (preserveView && selectedId) {
      for (var i = 0; i < displayModel.count; i++) {
        var row = displayModel.get(i)
        if (row.itemId === selectedId && row.section === selectedSection) {
          root.selectedIndex = i
          break
        }
      }
    }
    root.settleCursor()
    if (!preserveView || result.structural) {
      Qt.callLater(function() {
        if (displayModel.count > 0) root.revealCursor()
      })
    }
  }

  function rebuildDisplay(preserveView) {
    if (root.dmenuActive) {
      root.rebuildDmenuDisplay()
      return
    }

    if (!root.rowsLoaded) { MenuModel.syncDisplayRows(displayModel, []); return }

    if (root.appActionsMode) {
      var actionRows = []
      var actionQuery = root.filterText.trim().toLowerCase()
      for (var a = 0; a < root.appActions.length; a++) {
        var found = root.appActions[a]
        if (actionQuery && (found.name + " " + found.detail).toLowerCase().indexOf(actionQuery) < 0) continue
        actionRows.push({
          itemId: "app-action." + a, disabled: false, kind: "app-action",
          icon: "󰌌", iconFont: "", appIcon: String(root.appActionsPid), appId: JSON.stringify(found.path),
          label: found.name, target: found.actionName,
          detail: (found.detail || "Application action") + (found.binding ? " · " + found.binding : ""),
          path: found.detail, childCount: 0, action: String(found.actionIndex), provider: "",
          score: a, section: ""
        })
      }
      root.applyDisplayRows(actionRows, false)
      return
    }

    var active = root.item(root.activeMenu) ? root.activeMenu : "root"
    root.activeMenu = active
    var rows = []
    var query = root.filterText.trim()
    root.searchDivider = false

    if (query) {
      var searchSort = function(a, b) {
        if (a.score !== b.score) return a.score - b.score
        return a.path.localeCompare(b.path)
      }
      var prefix = MenuModel.launcherPrefix(query)
      if (active === "root" && prefix.kind === "web") {
        var web = MenuModel.webSearch(query)
        if (web) rows.push({ itemId: "search.web", disabled: false, kind: "web",
          icon: "󰖟", iconFont: "", appIcon: "", appId: "", label: web.label,
          target: web.url, detail: web.detail, path: "Web", childCount: 0,
          action: "", provider: "", score: 0, section: "WEB" })
      } else if (active === "root" && prefix.kind === "clipboard") {
        var clips = MenuModel.clipboardMatches(root.clipboardHistoryRaw, prefix.text)
        for (var c = 0; c < clips.length; c++) {
          var clip = clips[c]
          rows.push({ itemId: "search.clipboard." + clip.index, disabled: false, kind: "clipboard",
            icon: clip.type === "image" ? "󰋩" : "󰅍", iconFont: "", appIcon: clip.mime || "",
            appId: clip.path || "", label: clip.label, target: String(clip.index),
            detail: clip.detail, path: "Clipboard", childCount: 0, action: clip.type,
            provider: "", score: c, section: "CLIPBOARD" })
        }
      } else if (active === "root" && prefix.kind === "files") {
        for (var f = 0; f < root.fileResults.length; f++) {
          var filePath = String(root.fileResults[f] || "")
          if (!filePath) continue
          rows.push({ itemId: "search.file." + f, disabled: false, kind: "file",
            icon: "", iconFont: "", appIcon: "", appId: "",
            label: filePath.slice(filePath.lastIndexOf("/") + 1), target: filePath,
            detail: filePath, path: "Files", childCount: 0, action: "",
            provider: "", score: f, section: "FILES" })
        }
      } else {
        var currentRows = []
        var drilldownRows = []
        var groups = { "Settings": [], "Commands": [], "Apps": [], "Browse": [] }
        if (active === "root") {
          var answer = MenuModel.calculate(query)
          if (answer !== null) rows.push({
            itemId: "search.calculation", disabled: false, kind: "calculation",
            icon: "󰃬", iconFont: "", appIcon: "", appId: "",
            label: answer, target: answer, detail: "Enter to copy",
            path: "Calculator", childCount: 0, action: "", provider: "",
            score: -1, section: "ANSWER"
          })
        }
        for (var i = 0; i < root.itemOrder.length; i++) {
          var entry = root.item(root.itemOrder[i])
          if (!entry || entry.id === "root") continue
          if (!root.isDescendantOf(entry.id, active)) continue
          if (!root.matchesQuery(entry, query)) continue
          var detail = root.parentPathFor(entry.id)
          var row = root.displayRow(entry, detail, root.searchScore(entry, query) - root.usageBonus(entry.id))
          if (active === "root") groups[MenuModel.launcherGroup(entry)].push(row)
          else if (entry.parent === active) currentRows.push(row)
          else drilldownRows.push(row)
        }
        if (active === "root") {
          var groupOrder = ["Settings", "Commands", "Apps", "Browse"]
          for (var orderIndex = 0; orderIndex < groupOrder.length; orderIndex++) groups[groupOrder[orderIndex]].sort(searchSort)
          groupOrder.sort(function(a, b) {
            var left = groups[a].length ? groups[a][0].score : Infinity
            var right = groups[b].length ? groups[b][0].score : Infinity
            return left - right
          })
          for (var g = 0; g < groupOrder.length; g++) {
            var group = groups[groupOrder[g]]
            for (var x = 0; x < Math.min(group.length, 10); x++) {
              group[x].section = groupOrder[g].toUpperCase()
              rows.push(group[x])
            }
          }
          var matchingWindows = MenuModel.windowMatches(root.windowClients, query)
          for (var w = 0; w < matchingWindows.length; w++) {
            var win = matchingWindows[w]
            rows.push({ itemId: "search.window." + win.address, disabled: false, kind: "window",
              icon: "󰖯", iconFont: "", appIcon: "", appId: "", label: win.title,
              target: win.address, detail: win.app, path: "Windows", childCount: 0,
              action: "", provider: "", score: w, section: "WINDOWS" })
          }
        } else {
          currentRows.sort(searchSort)
          drilldownRows.sort(searchSort)
          root.searchDivider = currentRows.length > 0 && drilldownRows.length > 0
          if (root.searchDivider) {
            for (var d = 0; d < drilldownRows.length; d++) drilldownRows[d].section = "drilldown"
          }
          rows = currentRows.concat(drilldownRows)
        }
      }
    } else {
      for (var j = 0; j < root.itemOrder.length; j++) {
        var child = root.item(root.itemOrder[j])
        if (!child || child.parent !== active) continue
        if (!root.isVisible(child)) continue
        var plainRow = root.displayRow(child, child.description, child.order)
        if (active === "root") plainRow.section = "BROWSE"
        rows.push(plainRow)
      }

      // DesktopEntries can reorder its values when an application starts.
      // Keep the Apps menu alphabetical independently of provider refreshes.
      if (active === "apps") {
        rows.sort(function(a, b) {
          var aLabel = String(a.label || "").toLowerCase()
          var bLabel = String(b.label || "").toLowerCase()
          if (aLabel < bLabel) return -1
          if (aLabel > bLabel) return 1
          var aId = String(a.itemId || "")
          var bId = String(b.itemId || "")
          if (aId < bId) return -1
          if (aId > bId) return 1
          return 0
        })
      }
      if (active === "root") {
        var recent = []
        var usedEntries = root.usageState.entries || ({})
        var usedIds = Object.keys(usedEntries).sort(function(a, b) {
          return Number((usedEntries[b] || {}).last || 0) - Number((usedEntries[a] || {}).last || 0)
        })
        for (var ri = 0; ri < usedIds.length && recent.length < 5; ri++) {
          var used = root.item(usedIds[ri])
          if (!used || !root.isVisible(used) || root.isDisabled(used)) continue
          recent.push(root.displayRow(used, root.parentPathFor(used.id), ri, "RECENT"))
        }
        rows = recent.concat(rows)
      }
    }

    root.applyDisplayRows(rows, preserveView === true)
  }

  // Contain alone parks the cursor row flush with the viewport edge, hiding
  // the neighbor entirely and losing the fold affordance. Keep the next
  // hidden row peeking past the cursor in the direction of travel.
  function revealCursor() {
    if (displayModel.count === 0) return
    resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    // A native provider can grow the list before the card finishes resizing.
    // Keep the first row at the top instead of scrolling it away to peek at
    // its neighbor using the old, shorter viewport height.
    if (root.selectedIndex === 0) {
      resultList.contentY = resultList.originY
      return
    }

    var item = resultList.itemAtIndex(root.selectedIndex)
    if (!item) return

    var reach = root.rowPeek + root.rowSpacing
    if (root.selectedIndex < displayModel.count - 1) {
      var maxY = Math.max(resultList.originY, resultList.originY + resultList.contentHeight - resultList.height)
      var overhang = item.y + item.height + reach - (resultList.contentY + resultList.height)
      if (overhang > 0) resultList.contentY = Math.min(resultList.contentY + overhang, maxY)
    }
    if (root.selectedIndex > 0) {
      var underhang = resultList.contentY - (item.y - reach)
      if (underhang > 0) resultList.contentY = Math.max(resultList.contentY - underhang, resultList.originY)
    }
  }

  function select(delta) {
    if (displayModel.count === 0) return

    root.disarmPointer()
    var from = cursorActive ? selectedIndex + delta : (delta < 0 ? displayModel.count - 1 : 0)
    var target = root.nextSelectable(from, delta)
    if (target < 0) return

    cursorActive = true
    selectedIndex = target
    revealCursor()
  }

  function setFilter(nextFilter) {
    panel.freezeCardTop()
    root.filterText = nextFilter
    root.selectedIndex = 0
    root.cursorActive = root.mode !== "input"
    root.disarmPointer()
    var prefix = MenuModel.launcherPrefix(root.filterText)
    if (!root.dmenuActive && !root.appActionsMode && prefix.kind === "all" && root.filterText.trim()) root.loadProvidersForSearch()
    if (!root.dmenuActive && !root.appActionsMode && root.activeMenu === "root" && prefix.kind === "files" && prefix.text.length >= 2) {
      root.fileResults = []
      fileSearchDelay.restart()
    } else {
      fileSearchDelay.stop()
      root.fileResults = []
    }
    root.rebuildDisplay()
  }

  function setActiveMenu(id, pushHistory, fromPointer) {
    panel.freezeCardTop()
    if (!root.item(id)) id = "root"
    if (pushHistory && id !== root.activeMenu) root.navStack = root.navStack.concat([root.activeMenu])
    root.activeMenu = id
    root.filterText = ""
    root.selectedIndex = 0
    root.cursorActive = true
    if (fromPointer) pointerGate.allowInitialSample()
    else root.disarmPointer()
    root.rebuildDisplay()
    root.invalidateVolatileProvider(id)
    root.loadProviderForMenu(id)
  }

  function goBack() {
    if (root.activeMenu === "root") return false

    if (root.navStack.length > 0) {
      var previous = root.navStack[root.navStack.length - 1]
      root.navStack = root.navStack.slice(0, root.navStack.length - 1)
      root.setActiveMenu(previous, false)
      return true
    }

    var active = root.item(root.activeMenu)
    root.setActiveMenu((active && active.parent) ? active.parent : "root", false)
    return true
  }

  function activateIndex(index, fromPointer) {
    if (root.deleteConfirmOpen) return
    if (root.dmenuActive) {
      if (root.mode === "input") {
        root.applyDmenuSelection(root.filterText)
        return
      }
      if (index < 0 || index >= displayModel.count) return
      var picked = displayModel.get(index)
      root.applyDmenuSelection(picked.detail ? picked.label + "\t" + picked.detail : picked.label)
      return
    }

    if (!root.rowSelectable(index)) return

    var row = displayModel.get(index)
    if (root.item(row.itemId) && !root.isVisible(root.item(row.itemId))) return
    if (root.item(row.itemId) && row.kind !== "tray-toggle" && row.kind !== "plugin-toggle") root.recordUsage(row.itemId)
    if (row.itemId === "trigger.toggle.cast") {
      root.toggleCasting()
    } else if (row.itemId === "trigger.toggle.shortcut-guide") {
      root.toggleShortcutGuide()
    } else if (row.itemId === "trigger.toggle.osd") {
      root.disarmPointer()
      Quickshell.execDetached(["strata-toggle-osd"])
    } else if (row.kind === "tray-toggle") {
      root.toggleTrayVisibility(row.appId)
    } else if (row.kind === "plugin-toggle") {
      root.togglePlugin(row)
    } else if (row.kind === "menu" || row.kind === "link") {
      root.setActiveMenu(row.target || row.itemId, true, fromPointer)
    } else if (row.kind === "app-action") {
      var actionPid = row.appIcon
      var actionPath = row.appId
      var actionName = row.target
      var actionIndex = row.action
      root.cancel()
      Util.execArgv([root.strataPath + "/bin/strata-app-actions", "activate", actionPid, actionPath, actionIndex, actionName])
    } else if (row.kind === "calculation") {
      root.cancel()
      Util.execArgv(["wl-copy", row.target])
    } else if (row.kind === "file" || row.kind === "web") {
      root.cancel()
      Util.execArgv(["xdg-open", row.target])
    } else if (row.kind === "clipboard") {
      root.cancel()
      if (row.action === "image")
        Util.execArgv([root.strataPath + "/bin/strata-clipboard-paste-file", row.appIcon, row.appId])
      else
        Util.execArgv([root.strataPath + "/bin/strata-clipboard-paste-text", "--shift-insert", "--history-index", row.target])
    } else if (row.kind === "window") {
      root.cancel()
      if (/^0x[0-9a-f]+$/.test(row.target))
        Quickshell.execDetached(["hyprctl", "eval", 'hl.dispatch(hl.dsp.focus({ window = "address:' + row.target + '" }))'])
    } else if (row.kind === "app") {
      var appId = row.appId
      var label = row.label
      root.promoteShortcut({ appId: appId })
      applySerial = requestSerial
      opened = false
      filterText = ""
      if (root.appLibrary) root.appLibrary.launch(appId, label)
    } else {
      root.applySelected(row.itemId, row.action)
    }
  }

  function requestDeleteSelected() {
    if (!root.cursorActive || root.selectedIndex < 0 || root.selectedIndex >= displayModel.count) return
    var row = displayModel.get(root.selectedIndex)
    if (!row) return
    if (row.kind === "plugin-toggle") {
      var entry = root.item(row.itemId)
      if (!entry || entry.unavailable || pluginRemoval.running) return
      if (entry.pluginFirstParty && row.action !== "on") return
      root.deleteTarget = {kind:"plugin", appId:row.appId, label:row.label, mode:entry.pluginFirstParty ? "disable" : "remove"}
    } else if (row.kind === "app") root.deleteTarget = {kind:"app", appId:row.appId, label:row.label}
    else return
    deleteConfirm.selectedIndex = row.kind === "plugin-toggle" ? 0 : 1
    root.deleteConfirmOpen = true
  }

  function cancelDelete() {
    root.deleteConfirmOpen = false
    root.deleteTarget = null
    deleteConfirm.selectedIndex = 1
    root.disarmPointer()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function confirmDelete() {
    var target = root.deleteTarget
    root.deleteConfirmOpen = false
    root.deleteTarget = null
    if (!target) return
    if (target.kind === "plugin") {
      root.pluginError = ""
      if (target.mode === "disable" && target.appId === "strata.menu") {
        root.cancel()
        Quickshell.execDetached(["strata-shell", "shell", "setPluginEnabled", target.appId, "false"])
        return
      }
      if (target.mode === "disable") root.shell.pluginRegistry.setEnabled(target.appId, false)
      else {
        pluginRemoval.command = ["strata-plugin", "remove", target.appId]
        pluginRemoval.running = true
      }
      root.disarmPointer()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
      return
    }
    root.cancel()
    if (root.appLibrary) root.appLibrary.remove(target.appId, target.label)
  }

  function applyDmenuSelection(value) {
    applySerial = requestSerial
    opened = false
    filterText = ""
    root.finishRequest(value)
  }

  function applySelected(id, action) {
    if (!id) { cancel(); return }

    applySerial = requestSerial
    opened = false
    filterText = ""
    root.promoteShortcut({ command: action })
    root.runAction(action)
  }

  function cancel() {
    if (root.dmenuActive) root.finishRequest(null)
    opened = false
    filterText = ""
  }

  function openExistingMenu(initialMenu) {
    requestSerial += 1
    mode = "menu"
    requestActive = false
    selectionFile = ""
    doneFile = ""
    activeMenu = root.item(initialMenu) ? initialMenu : "root"
    navStack = []
    filterText = ""
    selectedIndex = 0
    cursorActive = true
    root.disarmPointer()
    root.evaluateGuards()
    root.windowClients = []
    root.fileResults = []
    fileSearchDelay.stop()
    if (!windowQuery.running) windowQuery.running = true
    opened = true
    rebuildDisplay()
    invalidateVolatileProvider(activeMenu)
    loadProviderForMenu(activeMenu)
    if (activeMenu === "root") loadProviderForMenu("apps")
    // The shell may start before first-install packages have finished placing
    // their icons. Refresh here even when the desktop entry list did not change.
    if (root.appLibrary) root.appLibrary.refreshIcons()

    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function openDmenu(payload) {
    requestSerial += 1
    mode = payload.mode === "input" ? "input" : "select"
    dmenuPrompt = String(payload.prompt || (mode === "input" ? "Input" : "Select"))
    dmenuDescription = String(payload.description || "")
    dmenuOptions = Array.isArray(payload.options) ? payload.options : []
    selectionFile = String(payload.selectionFile || "")
    doneFile = String(payload.doneFile || "")
    requestActive = !!doneFile
    dmenuWidth = Math.max(1, Number(payload.width || 300))
    dmenuMaxHeight = Math.max(0, Number(payload.maxHeight || 0))
    activeMenu = "root"
    navStack = []
    filterText = ""
    selectedIndex = 0
    cursorActive = mode !== "input"
    root.disarmPointer()
    opened = true
    rebuildDisplay()

    Qt.callLater(function() {
      if (root.mode === "input") inputField.forceActiveFocus()
      else keyCatcher.forceActiveFocus()
    })
  }

  function openAppActions(payload) {
    var pid = Number(payload.pid)
    if (!Number.isInteger(pid) || pid <= 0) return
    root.openExistingMenu("root")
    root.mode = "app-actions"
    root.appActionsPid = pid
    root.appActions = []
    root.rebuildDisplay()
    if (!appActionsQuery.running) root.startAppActionsQuery()
  }

  function startAppActionsQuery() {
    appActionsQuery.activePid = root.appActionsPid
    appActionsQuery.command = [root.strataPath + "/bin/strata-app-actions", "list", String(root.appActionsPid)]
    appActionsQuery.running = true
  }
  ListModel { id: displayModel }

  // ----------------------------------------------------------- route surface
  //
  // The menu is opened through the standard plugin lifecycle:
  // `strata-shell shell summon strata.menu '{"menu":"system"}'`.
  // Callers may pass a real id (`system`, `setup.power`) or an alias declared
  // in JSONC (`power`). Unknown strings fall through to the
  // id-as-route behavior so misspellings still attempt to open the literal id.
  function resolveRoute(input) {
    return MenuModel.resolveRoute(root.items, root.itemOrder, input)
  }

  function openRoute(initialMenu) {
    var id = root.resolveRoute(initialMenu)
    var entry = root.items[id]
    // If the resolved id is an action (i.e. the user invoked an alias for
    // a leaf, e.g. `strata menu summon screenrecord-stop`), run it directly
    // instead of opening an action with no children.
    if (entry && entry.kind === "action" && entry.action) {
      root.cancel()
      root.runAction(entry.action)
      return "ok"
    }
    // If it's a link (a redirect to another menu), follow the link.
    if (entry && entry.kind === "link" && entry.target) id = entry.target
    root.pendingInitialMenu = id
    root.openExistingMenu(id)
    return "ok"
  }

  function disarmPointer() {
    pointerGate.reset()
  }

  function selectFromPointer(index, item, mouse) {
    if (!pointerGate.moved(item, mouse)) return
    if (!root.rowSelectable(index)) return
    root.cursorActive = true
    root.selectedIndex = index
  }

  Process {
    id: pluginRemoval
    stderr: StdioCollector { id: pluginRemovalErrors; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0) root.pluginError = String(pluginRemovalErrors.text).trim() || "Could not remove plugin."
      if (root.shell && root.shell.pluginRegistry) root.shell.pluginRegistry.rescan()
    }
  }

  Process {
    id: providerProc
    property string menuId: ""
    property string providerKey: ""
    property string collected: ""
    property int revision: 0
    stdout: SplitParser {
      onRead: function(data) { providerProc.collected += data + "\n" }
    }
    onExited: {
      if (providerProc.revision === root.providerRevision) {
        root.mergeProviderRows(providerProc.collected, providerProc.menuId, providerProc.providerKey)
        if (root.filterText.trim()) root.loadProvidersForSearch()
      }
      root.startNextProvider()
    }
  }

  Process {
    id: windowQuery
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var clients = JSON.parse(String(text || "[]"))
          root.windowClients = Array.isArray(clients) ? clients : []
        } catch (e) { root.windowClients = [] }
        if (root.opened && root.filterText.trim()) root.rebuildDisplay()
      }
    }
  }

  FileView {
    id: clipboardHistoryFile
    path: Quickshell.env("HOME") + "/.local/state/strata/clipboard-history.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      root.clipboardHistoryRaw = text()
      if (root.opened && MenuModel.launcherPrefix(root.filterText).kind === "clipboard") root.rebuildDisplay()
    }
    onLoadFailed: root.clipboardHistoryRaw = "[]"
    onFileChanged: reload()
  }

  FileView {
    id: usageFile
    path: Quickshell.env("HOME") + "/.local/state/strata/menu-usage.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadUsage(text())
    onLoadFailed: root.loadUsage("{}")
    onFileChanged: reload()
  }

  Timer {
    id: fileSearchDelay
    interval: 180
    onTriggered: root.startFileSearch()
  }

  function startFileSearch() {
    var prefix = MenuModel.launcherPrefix(root.filterText)
    if (!root.opened || root.activeMenu !== "root" || prefix.kind !== "files" || prefix.text.length < 2) return
    if (fileSearchProc.running) return
    fileSearchProc.queryText = prefix.text
    fileSearchProc.command = [root.strataPath + "/bin/strata-menu-files", prefix.text]
    fileSearchProc.running = true
  }

  Process {
    id: fileSearchProc
    property string queryText: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var prefix = MenuModel.launcherPrefix(root.filterText)
        if (!root.opened || prefix.kind !== "files" || prefix.text !== fileSearchProc.queryText) return
        try {
          var paths = JSON.parse(String(text || "[]"))
          root.fileResults = Array.isArray(paths) ? paths : []
        } catch (e) { root.fileResults = [] }
        root.rebuildDisplay()
      }
    }
    onExited: {
      var prefix = MenuModel.launcherPrefix(root.filterText)
      if (root.opened && prefix.kind === "files" && prefix.text.length >= 2 && prefix.text !== queryText)
        Qt.callLater(function() { root.startFileSearch() })
    }
  }

  Process {
    id: appActionsQuery
    property int activePid: 0
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!root.opened || !root.appActionsMode || appActionsQuery.activePid !== root.appActionsPid) return
        try {
          var rows = JSON.parse(String(text || "[]"))
          root.appActions = Array.isArray(rows) ? rows : []
        } catch (e) { root.appActions = [] }
        if (root.opened && root.appActionsMode) root.rebuildDisplay()
      }
    }
    onExited: {
      if (root.opened && root.appActionsMode && activePid !== root.appActionsPid)
        Qt.callLater(function() {
          if (root.opened && root.appActionsMode && !appActionsQuery.running) root.startAppActionsQuery()
        })
    }
  }

  Process {
    id: resultProc
    onExited: {
      if (root.applySerial === root.requestSerial)
        root.opened = false
    }
  }

  PointerMoveGate {
    id: pointerGate
    referenceItem: card
  }

  Connections {
    target: root.shell ? root.shell.pluginRegistry : null
    function onPluginsChanged() {
      root.refreshPluginProviders()
      if (root.opened && !root.dmenuActive && !root.appActionsMode) root.rebuildDisplay(true)
    }
  }

  Connections {
    target: root.appLibrary
    function onAppsChanged() {
      if (root.providersLoaded["apps"]) root.mergeAppRows()
    }
  }

  // The JSONC sources are watched so live edits to the default file (or the
  // user extension at ~/.config/strata/extensions/strata-menu.jsonc) take
  // effect without restarting the shell.
  FileView {
    id: defaultMenuFile
    path: root.defaultMenuPath
    watchChanges: true
    printErrors: false
    onLoaded: { root.defaultMenuItems = root.parseMenuJsonc(text()); root.rebuildItemsFromSources() }
    onFileChanged: reload()
  }

  FileView {
    id: userMenuFile
    path: root.userMenuPath
    watchChanges: true
    printErrors: false
    onLoaded: { root.userMenuItems = root.parseMenuJsonc(text()); root.rebuildItemsFromSources() }
    onLoadFailed: { root.userMenuItems = []; root.rebuildItemsFromSources() }
    onFileChanged: reload()
  }

  // ---------------------------------------------------------------- guards
  //
  // `when:` (visibility) and `checked:` (✓ marker) are bash expressions the
  // shell wasn't allowed to evaluate before the perf rewrite. Now the shell
  // batches them into one bash subprocess per (re)load so the open path
  // never has to wait on them.

  property var whenResults: ({})       // id → true|false (allow visibility)
  property var checkedResults: ({})    // id → true|false (show ✓)
  property var disabledResults: ({})   // id → true|false (dim, skip cursor)
  property bool guardsPending: false

  function evaluateGuards() {
    // Process ignores a command change while it is running, and `collected`
    // belongs to the run in flight, so a second evaluation cannot overwrite
    // the first: it would throw away the lines already read and never start.
    // The surviving tail then lands as the whole answer, and every id lost
    // with it goes back to showing, since a `when:` only hides on an explicit
    // false. Wait for the run in flight and evaluate once it lands instead.
    if (guardProc.running) {
      root.guardsPending = true
      return
    }
    root.guardsPending = false

    var script = MenuModel.guardScript(root.items)
    if (!script) {
      root.whenResults = ({})
      root.checkedResults = ({})
      root.disabledResults = ({})
      return
    }
    guardProc.collected = ""
    guardProc.command = ["bash", "-lc", script]
    guardProc.running = true
  }

  Process {
    id: guardProc
    property string collected: ""
    stdout: SplitParser {
      onRead: function(data) { guardProc.collected += data + "\n" }
    }
    onExited: function(exitCode, exitStatus) {
      // A batch that was killed rather than finished has only told us about
      // the rows it reached, and a row whose `when:` went unanswered shows.
      // Keep the last complete set rather than let a half-read one through.
      // A signal leaves the exit code at 0, so the status is what tells us.
      if (exitCode !== 0 || exitStatus !== 0) {
        if (root.guardsPending) Qt.callLater(function() { root.evaluateGuards() })
        return
      }

      var nextWhen = ({})
      var nextChecked = ({})
      var nextDisabled = ({})
      var lines = guardProc.collected.split("\n")
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (!line) continue
        var colon = line.lastIndexOf(":")
        if (colon < 0) continue
        var value = line.substring(colon + 1) === "1"
        var rest = line.substring(0, colon)
        var tagAt = rest.lastIndexOf(":")
        if (tagAt < 0) continue
        var id = rest.substring(0, tagAt)
        var tag = rest.substring(tagAt + 1)
        if (tag === "w") nextWhen[id] = value
        else if (tag === "c") nextChecked[id] = value
        else if (tag === "d") nextDisabled[id] = value
      }
      root.whenResults = nextWhen
      root.checkedResults = nextChecked
      root.disabledResults = nextDisabled
      if (root.opened) root.rebuildDisplay()
      // Run the evaluation that had to stand aside. Deferred by a turn so the
      // process is settled before its command is set again.
      if (root.guardsPending) Qt.callLater(function() { root.evaluateGuards() })
    }
  }
  OverlayWindow {
    id: panel
    // Keep the inert surface fullscreen between opens. Resizing the default
    // 1x1 parked surface made Hyprland animate the scrim out of the top-left.
    parkWhenHidden: false
    shown: root.opened && root.rowsLoaded
    WlrLayershell.namespace: "strata-menu"

    // The card opens centered exactly as always. The first search keystroke
    // or submenu move freezes the top line where it currently sits — from
    // then on the card grows and shrinks downward instead of re-centering
    // on every resize, which made the menu jump around. The rows height is
    // frozen at the same moment, so the starting menu also caps how tall the
    // card may grow from there. Closing unfreezes both.
    property int cardTop: -1
    property int maxRowsHeight: -1
    readonly property int centeredTop: root.dmenuActive
      ? Math.max(Style.gapsOut, Math.round((height - root.cardHeight) / 2))
      : Math.max(Style.gapsOut, Math.round(height * 0.14))
    readonly property int effectiveCardTop: cardTop >= 0 ? cardTop : centeredTop
    function freezeCardTop() {
      if (shown && cardTop < 0) {
        cardTop = effectiveCardTop
        maxRowsHeight = root.visibleRowsHeight
      }
    }
    // The surface stays mapped between opens, so closing is shown going false.
    onShownChanged: if (!shown) { cardTop = -1; maxRowsHeight = -1 }

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.cancel()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: Math.min(root.cardHeight, panel.height - Style.gapsOut - panel.effectiveCardTop)
      radius: root.cornerRadius
      anchors.horizontalCenter: parent.horizontalCenter
      y: panel.effectiveCardTop
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        z: root.deleteConfirmOpen ? 20 : 0
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (root.deleteConfirmOpen) {
            if (deleteConfirm.handleKey(event)) event.accepted = true
            return
          }

          if (event.key === Qt.Key_Delete) {
            root.requestDeleteSelected()
            event.accepted = true
          } else if (event.key === Qt.Key_Escape) {
            if (root.filterText) root.setFilter("")
            else root.cancel()
            event.accepted = true
          } else if (!root.hasDmenuDescription && Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if ((event.key === Qt.Key_Backspace || event.key === Qt.Key_Left) && !root.filterText) {
            root.goBack()
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            root.select(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            root.select(1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageUp) {
            root.select(-6)
            event.accepted = true
          } else if (event.key === Qt.Key_PageDown) {
            root.select(6)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Right) {
            if (root.dmenuActive) {
              if (root.mode === "input") root.applyDmenuSelection(root.filterText)
              else if (displayModel.count > 0) root.activateIndex(root.cursorActive ? root.selectedIndex : 0)
            } else if (root.cursorActive) root.activateIndex(root.selectedIndex)
            else root.settleCursor()
            event.accepted = true
          } else if (!root.hasDmenuDescription && event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127 && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier)) {
            root.setFilter(root.filterText + event.text)
            event.accepted = true
          }
        }

        ConfirmDialog {
          id: deleteConfirm

          anchors.fill: parent
          opened: root.deleteConfirmOpen
          z: 10
          message: root.deleteTarget && root.deleteTarget.kind === "plugin"
            ? (root.deleteTarget.mode === "disable"
              ? (root.deleteTarget.appId === "strata.menu" ? "Disable the menu? Restore with: strata-shell shell setPluginEnabled strata.menu true"
                : root.deleteTarget.label + " is built-in. Disable it? Its packaged files and saved settings will be kept.")
              : "Remove " + root.deleteTarget.label + "? Its installed plugin files will be deleted.")
            : "Do you want to uninstall " + ((root.deleteTarget && root.deleteTarget.label) || "") + "?"
          confirmText: root.deleteTarget && root.deleteTarget.mode === "disable" ? "Disable" : "Uninstall"
          background: root.background
          foreground: root.foreground
          scrim: root.scrim
          selectedBackground: root.selectedBackground
          selectedText: root.selectedText
          fontFamily: root.fontFamily
          cornerRadius: root.cornerRadius
          onCanceled: root.cancelDelete()
          onConfirmed: root.confirmDelete()
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        Rectangle {
          width: parent.width
          height: root.headerHeight
          radius: root.cornerRadius
          color: root.hasDmenuDescription ? "transparent" : Util.alpha(root.foreground, 0.055)
          border.color: Util.alpha(root.border, 0.65)
          border.width: root.hasDmenuDescription ? 0 : 1

          Text {
            visible: root.mode !== "input" || !root.filterText
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.leftMargin: Style.space(16)
            anchors.right: parent.right
            anchors.rightMargin: Style.space(16)
            anchors.verticalCenter: parent.verticalCenter
            text: root.hasDmenuDescription ? root.dmenuPrompt : (root.filterText || (root.appActionsMode ? "Search app actions…" : (root.dmenuActive ? (root.dmenuPrompt + "…") : (root.activeMenu === "root" ? "Search apps, commands, files…" : ((root.item(root.activeMenu) ? (root.item(root.activeMenu).title || root.item(root.activeMenu).label) : "Go") + "…")))))
            color: root.foreground
            opacity: root.hasDmenuDescription || root.filterText ? 1 : 0.58
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            elide: Text.ElideRight
          }

          TextInput {
            id: inputField
            visible: root.dmenuActive && root.mode === "input"
            anchors.left: parent.left
            anchors.leftMargin: Style.space(16)
            anchors.right: parent.right
            anchors.rightMargin: Style.space(16)
            anchors.verticalCenter: parent.verticalCenter
            text: root.filterText
            color: root.foreground
            selectionColor: root.selectedBackground
            selectedTextColor: root.selectedText
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            selectByMouse: true
            clip: true
            onTextEdited: root.setFilter(text)
            onAccepted: root.applyDmenuSelection(text)
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) {
                if (root.filterText) root.setFilter("")
                else root.cancel()
                event.accepted = true
              } else if (event.key === Qt.Key_V && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
                paste()
                event.accepted = true
              }
            }
          }

        }

        Flickable {
          width: parent.width
          height: root.dmenuDescriptionHeight
          visible: root.hasDmenuDescription
          clip: true
          contentWidth: width
          contentHeight: descriptionText.implicitHeight
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick
          interactive: contentHeight > height
          Controls.ScrollBar.vertical: PanelScrollBar {}

          Text {
            id: descriptionText
            x: Style.space(16)
            width: Math.max(0, parent.width - Style.space(32))
            textFormat: Text.PlainText
            text: root.hasDmenuDescription ? root.dmenuDescription : ""
            color: root.foreground
            opacity: 0.7
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.Wrap
          }
        }

        Item {
          width: parent.width
          height: root.visibleRowsHeight

          ListView {
            id: resultList
            Controls.ScrollBar.vertical: PanelScrollBar {
              // The list is inset for its rows; keep the rail by the card
              // border and outside the list's clipping rectangle.
              parent: resultList.parent
              anchors.top: resultList.top
              anchors.bottom: resultList.bottom
              anchors.right: parent.right
              anchors.rightMargin: Style.space(4) - card.rightPadding
              width: thickness
            }
            anchors.fill: parent
            model: displayModel
            clip: true
            spacing: root.rowSpacing
            boundsBehavior: Flickable.StopAtBounds

            // Keep section headers inside their row. Qt's native ListView
            // section cache can retain a stale delegate during model moves.
            delegate: Item {
              id: row
              required property int index
              required property string section
              required property string itemId
              required property string kind
              required property string icon
              required property string iconFont
              required property string appIcon
              required property string appId
              required property string label
              required property string target
              required property string detail
              required property string path
              required property string action
              required property int childCount
              required property bool disabled

              readonly property bool hasCursor: root.cursorActive && row.index === root.selectedIndex
              readonly property bool isApp: row.kind === "app"
              readonly property bool isCastToggle: row.itemId === "trigger.toggle.cast"
              readonly property bool isGuideToggle: row.itemId === "trigger.toggle.shortcut-guide"
              readonly property bool isOsdToggle: row.itemId === "trigger.toggle.osd"
              readonly property bool isTray: row.kind === "tray-toggle" || isCastToggle || isGuideToggle || isOsdToggle
              readonly property bool isToggleRow: isTray || row.kind === "plugin-toggle"
              readonly property bool hasIcon: row.icon.length > 0 || row.isApp

              readonly property string headerText: {
                root.layoutSerial
                if (!row.section || row.index < 0 || row.index >= displayModel.count) return ""
                var previous = row.index > 0 ? displayModel.get(row.index - 1) : null
                return !previous || previous.section !== row.section ? row.section : ""
              }
              width: ListView.view.width
              height: rowHeader.height + rowSurface.height

              Item {
                id: rowHeader
                width: parent.width
                height: row.headerText === "drilldown" ? root.dividerHeight : (row.headerText ? root.sectionHeight : 0)
                visible: height > 0

                Rectangle {
                  visible: row.headerText === "drilldown"
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(4)
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(4)
                  anchors.verticalCenter: parent.verticalCenter
                  height: Style.spacing.hairline
                  color: Util.alpha(root.foreground, 0.2)
                }

                Text {
                  visible: row.headerText !== "drilldown"
                  textFormat: Text.PlainText
                  text: row.headerText
                  color: root.foreground
                  opacity: 0.52
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.weight: Font.DemiBold
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(12)
                  anchors.bottom: parent.bottom
                  anchors.bottomMargin: Style.space(4)
                }
              }

              BorderSurface {
                id: rowSurface
                width: parent.width
                y: rowHeader.height
                height: root.rowHeightForDetail(row.detail, row.kind)
                opacity: row.disabled ? 0.4 : 1
                radius: root.cornerRadius
                color: row.hasCursor ? root.selectedBackground : "transparent"
                borderSpec: row.hasCursor ? root.selectedBorderSpec : Border.none()

                Rectangle {
                  visible: false
                  width: Style.space(4)
                  height: parent.height - Style.space(18)
                  radius: Math.min(root.cornerRadius, Style.space(4))
                  color: root.selectedBackground
                  anchors.left: parent.left
                  anchors.leftMargin: root.rowReservedBorderLeft + Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  id: iconText
                  textFormat: Text.PlainText
                  visible: row.hasIcon && !row.isApp
                  text: row.icon
                  color: row.hasCursor ? root.selectedText : root.foreground
                  font.family: row.iconFont.length > 0 ? row.iconFont : root.fontFamily
                  font.pixelSize: Style.font.iconLarge
                  width: Style.space(36)
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                  anchors.left: parent.left
                  anchors.leftMargin: root.rowReservedBorderLeft + Style.space(8)
                  y: contentColumn.y + labelText.y + (labelText.height - height) / 2
                }

                Image {
                  id: appIconImage
                  visible: row.isApp
                  width: Style.font.iconLarge
                  height: Style.font.iconLarge
                  fillMode: Image.PreserveAspectFit
                  // Decode at physical pixels — a logical-size decode leaves
                  // PNG icons upscaled and blurry on HiDPI displays.
                  sourceSize.width: width * Screen.devicePixelRatio
                  sourceSize.height: height * Screen.devicePixelRatio
                  source: row.isApp && root.appLibrary ? root.appLibrary.iconSource(row.appIcon) : ""
                  asynchronous: true
                  anchors.left: parent.left
                  anchors.leftMargin: root.rowReservedBorderLeft + Style.space(8) + (Style.space(36) - width) / 2
                  y: contentColumn.y + labelText.y + (labelText.height - height) / 2
                }

                Column {
                  id: contentColumn
                  anchors.left: row.hasIcon ? iconText.right : parent.left
                  anchors.leftMargin: row.hasIcon ? Style.space(6) : root.rowReservedBorderLeft + Style.space(18)
                  anchors.right: trail.left
                  anchors.rightMargin: Style.space(6)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(3)

                  Text {
                    id: labelText
                    textFormat: Text.PlainText
                    width: parent.width
                    text: row.label
                    color: row.hasCursor ? root.selectedText : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.heading
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                  }

                  Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    text: row.detail
                    visible: (root.filterText || row.kind === "dmenu" || row.kind === "app-action" || row.isToggleRow) && row.detail.length > 0
                    color: root.foreground
                    opacity: 0.52
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    elide: Text.ElideRight
                  }
                }

                Row {
                  id: trail
                  width: row.isToggleRow ? trayToggle.implicitWidth : Style.space(14)
                  anchors.right: parent.right
                  anchors.rightMargin: root.rowReservedBorderRight + Style.space(8)
                  y: row.isToggleRow ? (parent.height - height) / 2 : contentColumn.y + labelText.y + (labelText.height - height) / 2
                  spacing: 0

                  Text {
                    textFormat: Text.PlainText
                    visible: false
                    text: row.childCount
                    color: root.foreground
                    opacity: 0.45
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: row.kind === "menu" || row.kind === "link" ? "›" : ""
                    visible: !row.isToggleRow
                    color: row.hasCursor ? root.selectedText : root.foreground
                    opacity: row.kind === "menu" || row.kind === "link" ? 0.36 : 0
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.heading
                    font.weight: Font.Normal
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  ToggleSwitch {
                    id: trayToggle
                    visible: row.isToggleRow
                    checked: row.isCastToggle ? root.castingEnabled : row.isGuideToggle ? root.shortcutGuideEnabled : row.isOsdToggle ? root.osdEnabled : row.action === "on"
                    interactive: false
                    foreground: row.hasCursor ? root.selectedText : root.foreground
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                MouseArea {
                  id: mouseArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: row.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                  onEntered: root.selectFromPointer(row.index, rowSurface, {
                    x: mouseArea.mouseX,
                    y: mouseArea.mouseY
                  })
                  onPositionChanged: function(mouse) {
                    root.selectFromPointer(row.index, rowSurface, mouse)
                  }
                  onClicked: {
                    if (row.disabled) return
                    root.cursorActive = true
                    root.selectedIndex = row.index
                    root.activateIndex(row.index, true)
                  }
                }
              }
            }
          }

          // Scroll scrims. The clipped row already marks the fold at rest;
          // these keep both edges honest once the list has been scrolled,
          // when content hides above the card top as well as below. Strength
          // tracks the distance still hidden past each edge rather than
          // animating on a clock, so a programmatic jump — wrapping from the
          // last row back to the first — lands with the fade already applied.
          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Math.min(Style.space(28), parent.height / 2)
            visible: opacity > 0
            opacity: resultList.contentHeight > resultList.height
              ? Math.max(0, Math.min(1, (resultList.contentY - resultList.originY) / height))
              : 0
            gradient: Gradient {
              GradientStop { position: 0; color: root.background }
              GradientStop { position: 1; color: Util.alpha(root.background, 0) }
            }
          }

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.min(Style.space(28), parent.height / 2)
            visible: opacity > 0
            opacity: resultList.contentHeight > resultList.height
              ? Math.max(0, Math.min(1, (resultList.originY + resultList.contentHeight - resultList.height - resultList.contentY) / height))
              : 0
            gradient: Gradient {
              GradientStop { position: 0; color: Util.alpha(root.background, 0) }
              GradientStop { position: 1; color: root.background }
            }
          }

          Column {
            anchors.centerIn: parent
            spacing: Style.space(8)
            visible: displayModel.count === 0 && root.mode !== "input"

            Text {
              text: "󰈉"
              color: root.selectedText
              opacity: 0.8
              font.family: root.fontFamily
              font.pixelSize: Style.font.displayLarge
              horizontalAlignment: Text.AlignHCenter
              width: Style.space(320)
            }

            Text {
              textFormat: Text.PlainText
              text: {
                var prefix = MenuModel.launcherPrefix(root.filterText)
                if (prefix.kind === "files" && prefix.text.length < 2) return "Type at least 2 letters to find files"
                if (prefix.kind === "files" && (fileSearchDelay.running || fileSearchProc.running)) return "Searching files…"
                return root.filterText ? "No matches for “" + root.filterText + "”" : (root.appActionsMode ? "No app actions available" : "Nothing here yet")
              }
              color: root.foreground
              opacity: 0.7
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              horizontalAlignment: Text.AlignHCenter
              width: Style.space(320)
            }
          }
        }

        Item {
          width: parent.width
          height: root.dmenuActive ? 0 : root.footerHeight
          visible: !root.dmenuActive

          Text {
            textFormat: Text.PlainText
            text: root.pluginError || (root.appActionsMode ? "Enter run  ·  Esc close" : root.item(root.activeMenu) && root.item(root.activeMenu).provider === "plugins" ? "Enter toggle  ·  Del remove  ·  Esc close" : root.item(root.activeMenu) && root.item(root.activeMenu).provider === "tray-icons" ? "Enter toggle  ·  Esc close" : "Enter open  ·  Esc close")
            color: root.pluginError ? Color.urgent : root.foreground
            width: root.pluginError ? parent.width : implicitWidth
            elide: Text.ElideRight
            opacity: 0.45
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            textFormat: Text.PlainText
            text: "~ files  ·  cb clipboard  ·  g web"
            visible: !root.appActionsMode && root.activeMenu === "root"
            color: root.foreground
            opacity: 0.45
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }
  }
}

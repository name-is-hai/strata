function stripJsonc(raw) {
  var input = String(raw || "")
  var output = "", quoted = false, escaped = false, line = false, block = false
  for (var i = 0; i < input.length; i++) {
    var c = input.charAt(i), next = input.charAt(i + 1)
    if (line) {
      if (c === "\n" || c === "\r") { line = false; output += c }
      continue
    }
    if (block) {
      if (c === "*" && next === "/") { block = false; i++ }
      else if (c === "\n" || c === "\r") output += c
      continue
    }
    if (quoted) {
      output += c
      if (escaped) escaped = false
      else if (c === "\\") escaped = true
      else if (c === '"') quoted = false
      continue
    }
    if (c === '"') quoted = true
    else if (c === "/" && next === "/") { line = true; output += " "; i++; continue }
    else if (c === "/" && next === "*") { block = true; output += " "; i++; continue }
    output += c
  }
  if (block) return ""
  var result = ""
  quoted = false; escaped = false
  for (var j = 0; j < output.length; j++) {
    var value = output.charAt(j)
    if (!quoted && value === ",") {
      var k = j + 1
      while (/\s/.test(output.charAt(k)) && k < output.length) k++
      if (output.charAt(k) === "}" || output.charAt(k) === "]") continue
    }
    result += value
    if (quoted && escaped) escaped = false
    else if (quoted && value === "\\") escaped = true
    else if (value === '"') quoted = !quoted
  }
  return result
}

function normalizeAliases(value) {
  if (Array.isArray(value)) return value.filter(function(v) { return v })
  if (typeof value === "string" && value) return [value]
  return []
}

function normalizeItem(id, raw) {
  var value = raw || {}
  var aliases = normalizeAliases(value.aliases)
  var parent = value.parent
  if (parent === undefined)
    parent = id.indexOf(".") >= 0 ? id.split(".").slice(0, -1).join(".") : "root"
  if (id === "root") parent = ""

  var kind = value.action ? "action" : (value.target ? "link" : "menu")

  return {
    id: id,
    parent: parent,
    kind: kind,
    icon: value.icon || "",
    iconFont: value.iconFont || "",
    label: value.label || id,
    title: value.title || "",
    target: value.target || "",
    description: value.description || "",
    action: value.action || "",
    plugin: value.plugin === undefined ? String((pluginAction(value.action) || {}).id || "") : String(value.plugin || ""),
    provider: value.provider || "",
    aliases: aliases,
    when: value.when || "",
    checked: value.checked || "",
    disabled: value.disabled || ""
  }
}

function parseMenuJsonc(raw) {
  var stripped = stripJsonc(raw)
  if (!stripped.trim()) return []

  var parsed
  try {
    parsed = JSON.parse(stripped)
  } catch (e) {
    return []
  }
  if (typeof parsed !== "object" || parsed === null) return []

  var source = (parsed.items && typeof parsed.items === "object" && !Array.isArray(parsed.items))
    ? parsed.items
    : parsed
  var out = []
  for (var id in source) {
    var entry = source[id]
    if (!entry || typeof entry !== "object" || Array.isArray(entry)) continue
    var normalized = normalizeItem(id, entry)
    normalized.__fields = Object.keys(entry)
    out.push(normalized)
  }
  return out
}

function mergeMenuSources(defaultItems, userItems) {
  var nextItems = ({})
  var nextOrder = []
  var sources = [defaultItems || [], userItems || []]

  for (var s = 0; s < sources.length; s++) {
    var src = sources[s]
    for (var i = 0; i < src.length; i++) {
      var entry = src[i]
      if (!entry || !entry.id) continue
      if (!nextItems[entry.id]) nextOrder.push(entry.id)
      var prior = nextItems[entry.id] || {}
      var merged = {}
      for (var k in prior) merged[k] = prior[k]
      // Only explicitly supplied fields override an existing row. Inferred
      // empty defaults must not erase its label, icon, guards or aliases.
      var fields = entry.__fields || Object.keys(entry)
      for (var f = 0; f < fields.length; f++) {
        var key = fields[f]
        if (key !== "__fields") merged[key] = entry[key]
      }
      if (fields.indexOf("action") !== -1 && fields.indexOf("plugin") === -1)
        merged.plugin = String((pluginAction(merged.action) || {}).id || "")
      nextItems[entry.id] = normalizeItem(entry.id, merged)
    }
  }

  if (!nextItems.root) {
    nextItems.root = { id: "root", parent: "", kind: "menu", icon: "", iconFont: "", label: "Go", title: "", target: "", description: "", aliases: [], when: "", checked: "", disabled: "", action: "", provider: "" }
    nextOrder.unshift("root")
  }
  for (var k3 = 0; k3 < nextOrder.length; k3++) nextItems[nextOrder[k3]].order = k3

  return {
    items: nextItems,
    itemOrder: nextOrder
  }
}

// Both merges below return fresh items/itemOrder objects for the caller to
// assign in one go. They must never write into the maps they are handed: those
// live in QML `var` properties, and an in-place write into such an object is
// occasionally dropped by the engine — the key lands with an undefined value.
// A lost write used to leave an id in itemOrder with no item behind it, and
// the next merge then kept that orphan and appended a second row for the same
// app, so the launcher listed it twice (and again on every later rescan).

// Swaps every app row for the current set. Rows keep the order they arrive in;
// ids already claimed (including duplicate desktop ids) are listed once.
function mergeAppRows(items, itemOrder, appRows) {
  var source = items || ({})
  var order = Array.isArray(itemOrder) ? itemOrder : []
  var rows = Array.isArray(appRows) ? appRows : []
  var nextItems = ({})
  var nextOrder = []

  for (var i = 0; i < order.length; i++) {
    var id = order[i]
    var existing = source[id]
    // Orphans (an id with no item) are dropped rather than carried forward,
    // so a single lost write cannot compound into a duplicate row.
    if (!existing || existing.kind === "app") continue
    nextItems[id] = existing
    nextOrder.push(id)
  }

  for (var j = 0; j < rows.length; j++) {
    var row = rows[j]
    if (!row || !row.id || nextItems[row.id]) continue
    row.order = nextOrder.length
    nextItems[row.id] = row
    nextOrder.push(row.id)
  }

  return { items: nextItems, itemOrder: nextOrder }
}

// Swaps the rows one provider contributed, leaving every other item untouched.
// Rows carry the id of the submenu that produced them, so a provider that runs
// again drops its previous batch — a plugin that was just enabled disappears
// from the Enable list — without disturbing static children declared in JSONC.
function swapProviderRows(items, itemOrder, menuId, rows) {
  var source = items || ({})
  var order = Array.isArray(itemOrder) ? itemOrder : []
  var incoming = Array.isArray(rows) ? rows : []
  var nextItems = ({})
  var nextOrder = []

  for (var i = 0; i < order.length; i++) {
    var id = order[i]
    var existing = source[id]
    if (!existing || existing.providerMenu === menuId) continue
    nextItems[id] = existing
    nextOrder.push(id)
  }

  for (var j = 0; j < incoming.length; j++) {
    var row = incoming[j]
    if (!row || !row.id || nextItems[row.id]) continue
    row.providerMenu = menuId
    row.order = nextOrder.length
    nextItems[row.id] = row
    nextOrder.push(row.id)
  }

  return { items: nextItems, itemOrder: nextOrder }
}

function item(items, id) {
  return items && items[id] ? items[id] : null
}

// Routes may name a real id (`system`, `setup.power`) or an alias declared in
// JSONC (`power-menu`, `settings`). An exact id beats any alias, and app rows
// are never routable: their aliases carry .desktop Keywords and GenericName
// for search, so an installed application could otherwise shadow a menu route
// (htop ships `Keywords=system;...`). Unknown strings fall through as the
// literal input so misspellings still attempt to open that id.
function resolveRoute(items, itemOrder, input) {
  var raw = String(input || "").toLowerCase().replace(/_/g, "-")
  if (!raw || raw === "go" || raw === "menu") return "root"
  if (item(items, raw)) return raw
  var order = Array.isArray(itemOrder) ? itemOrder : []
  for (var i = 0; i < order.length; i++) {
    var entry = item(items, order[i])
    if (!entry || entry.kind === "app" || !entry.aliases) continue
    for (var j = 0; j < entry.aliases.length; j++) {
      var alias = String(entry.aliases[j] || "").toLowerCase().replace(/_/g, "-")
      if (alias === raw) return entry.id
    }
  }
  return raw
}

function slugify(value) {
  return String(value || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") || "item"
}

function depthFor(items, id) {
  var depth = 0
  var current = item(items, id)
  var guard = 0

  while (current && current.parent && current.parent !== "root" && guard < 32) {
    depth += 1
    current = item(items, current.parent)
    guard += 1
  }

  return depth
}

function pathFor(items, id) {
  var labels = []
  var current = item(items, id)
  var guard = 0

  while (current && current.id !== "root" && guard < 32) {
    labels.unshift(current.label)
    current = item(items, current.parent)
    guard += 1
  }

  return labels.join(" › ")
}

function parentPathFor(items, id) {
  var entry = item(items, id)
  if (!entry || !entry.parent || entry.parent === "root") return ""
  return pathFor(items, entry.parent)
}

function isDescendantOf(items, id, ancestorId) {
  if (ancestorId === "root") return id !== "root"

  var current = item(items, id)
  var guard = 0
  while (current && current.parent && guard < 32) {
    if (current.parent === ancestorId) return true
    current = item(items, current.parent)
    guard += 1
  }

  return false
}

function childCount(items, itemOrder, id) {
  var count = 0
  var order = Array.isArray(itemOrder) ? itemOrder : []
  for (var i = 0; i < order.length; i++) {
    var entry = item(items, order[i])
    if (entry && entry.parent === id) count += 1
  }
  return count
}

function isVisible(items, itemOrder, whenResults, entry, depth, pluginEnabled) {
  if (!entry) return false
  if (entry.plugin && pluginEnabled && !pluginEnabled(entry.plugin)) return false
  if (entry.when && whenResults && whenResults[entry.id] === false) return false
  if (entry.kind !== "menu" && entry.kind !== "link") return true
  if (entry.provider) return true

  var guard = depth || 0
  if (guard >= 32) return false

  var target = entry.kind === "link" ? entry.target : entry.id
  var order = Array.isArray(itemOrder) ? itemOrder : []
  for (var i = 0; i < order.length; i++) {
    var child = item(items, order[i])
    if (child && child.parent === target && isVisible(items, itemOrder, whenResults, child, guard + 1, pluginEnabled)) return true
  }

  return false
}

// A `disabled:` row stays listed but goes dim and unselectable. The
// Install submenus use it so software already on the machine reads as
// installed rather than disappearing from the list it was installed from.
function isDisabled(disabledResults, entry) {
  if (entry && entry.unavailable === true) return true
  if (!entry || !entry.disabled) return false
  return !!(disabledResults && disabledResults[entry.id])
}

// A disabled row is software you already have, which is the same thing the ✓
// says everywhere else in the menu, so it earns the same marker.
function labelFor(entry, checkedResults, disabledResults) {
  if (!entry) return ""
  var marked = (entry.checked && checkedResults && checkedResults[entry.id]) || isDisabled(disabledResults, entry)
  return marked ? entry.label + " ✓" : entry.label
}

function searchableToken(value) {
  return String(value || "").replace(/[._-]+/g, " ")
}

function leafIdFor(id) {
  var parts = String(id || "").split(".")
  return parts.length > 0 ? parts[parts.length - 1] : id
}

function nameSearchText(entry) {
  if (!entry) return ""
  var aliases = []
  var values = Array.isArray(entry.aliases) ? entry.aliases : []
  for (var i = 0; i < values.length; i++) aliases.push(searchableToken(values[i]))
  return [entry.label, searchableToken(leafIdFor(entry.id)), aliases.join(" ")].join(" ").toLowerCase()
}

function termInSearchWords(term, text) {
  var words = String(text || "").toLowerCase().split(/\s+/)
  for (var i = 0; i < words.length; i++) {
    if (words[i] === term) return true
  }
  return false
}

function descriptionTextMatches(query, text) {
  var terms = String(query || "").toLowerCase().trim().split(/\s+/)
  for (var i = 0; i < terms.length; i++) {
    if (terms[i] && !termInSearchWords(terms[i], text)) return false
  }
  return true
}

function matchesQuery(entry, query, visible) {
  if (!entry || entry.id === "root") return false
  if (!visible) return false

  var nameText = nameSearchText(entry)
  var descriptionText = String(entry.description || "").toLowerCase()
  var terms = String(query || "").toLowerCase().trim().split(/\s+/)

  for (var i = 0; i < terms.length; i++) {
    if (!terms[i]) continue
    if (nameText.indexOf(terms[i]) >= 0) continue
    if (termInSearchWords(terms[i], descriptionText)) continue
    return false
  }

  return true
}

function searchScore(items, entry, query) {
  var needle = String(query || "").toLowerCase().trim()
  var label = entry.label.toLowerCase()
  var nameText = nameSearchText(entry)
  var descriptionText = String(entry.description || "").toLowerCase()
  var score = 80

  if (label === needle) score = entry.parent === "root" ? 2 : 0
  // An installed app whose name contains the query as a whole word ("zen"
  // for Zen Browser) beats exact-labeled menu entries like Install > Zen.
  else if (entry.kind === "app" && label.split(/\s+/).indexOf(needle) >= 0) score = 0
  else if (label.indexOf(needle) === 0) score = 10
  else if (label.indexOf(needle) >= 0) score = 30
  else if (nameText.indexOf(needle) >= 0) score = 40
  else if (descriptionTextMatches(needle, descriptionText)) score = 60

  if (entry.kind === "menu" || entry.kind === "link") score -= 2
  // App rows sort after all menu items, so they lose the tiebreak below to an
  // equal match. Outrank those, but stay inside the tier so better ones win.
  if (entry.kind === "app") score -= 5

  return score * 1000 + depthFor(items, entry.id) * 25 + entry.order
}

function displayRow(items, itemOrder, checkedResults, disabledResults, entry, detail, score, section) {
  var target = entry.kind === "link" ? entry.target : entry.id
  return {
    itemId: entry.id,
    disabled: isDisabled(disabledResults, entry),
    kind: entry.kind,
    icon: entry.icon,
    iconFont: entry.iconFont || "",
    appIcon: entry.appIcon || "",
    appId: entry.appId || "",
    label: labelFor(entry, checkedResults, disabledResults),
    target: target,
    detail: detail || "",
    path: pathFor(items, entry.id),
    childCount: (entry.kind === "menu" || entry.kind === "link") ? childCount(items, itemOrder, target) : 0,
    action: entry.action || "",
    provider: entry.provider || "",
    score: score || 0,
    section: section || ""
  }
}

// Keep arithmetic local and deliberately small: a launcher query must never
// be evaluated as JavaScript or passed to a shell. An initial '=' opts in.
function calculate(query) {
  var input = String(query || "").trim()
  if (input.charAt(0) !== "=") return null
  var expression = input.slice(1).replace(/\s+/g, "")
  if (!expression || !/^[0-9.+*/()%\-]+$/.test(expression)) return null
  var pos = 0
  function number() {
    var start = pos
    while (/[0-9.]/.test(expression.charAt(pos)) && pos < expression.length) pos++
    if (start === pos) throw new Error("number expected")
    var raw = expression.slice(start, pos)
    if (!/^(?:\d+(?:\.\d*)?|\.\d+)$/.test(raw)) throw new Error("invalid number")
    return Number(raw)
  }
  function factor() {
    if (expression.charAt(pos) === "+") { pos++; return factor() }
    if (expression.charAt(pos) === "-") { pos++; return -factor() }
    if (expression.charAt(pos) === "(") {
      pos++
      var value = sum()
      if (expression.charAt(pos) !== ")") throw new Error("missing parenthesis")
      pos++
      return value
    }
    return number()
  }
  function product() {
    var value = factor()
    while (pos < expression.length) {
      var op = expression.charAt(pos)
      if (op !== "*" && op !== "/" && op !== "%") break
      pos++
      var right = factor()
      value = op === "*" ? value * right : op === "/" ? value / right : value % right
    }
    return value
  }
  function sum() {
    var value = product()
    while (pos < expression.length) {
      var op = expression.charAt(pos)
      if (op !== "+" && op !== "-") break
      pos++
      var right = product()
      value = op === "+" ? value + right : value - right
    }
    return value
  }
  try {
    var answer = sum()
    if (pos !== expression.length || !Number.isFinite(answer)) return null
    return String(Number(answer.toPrecision(12)))
  } catch (e) { return null }
}

function windowMatches(clients, query) {
  var needle = String(query || "").trim().toLowerCase()
  if (!needle || !Array.isArray(clients)) return []
  var rows = []
  for (var i = 0; i < clients.length; i++) {
    var client = clients[i]
    if (!client || client.mapped === false || client.hidden === true) continue
    if (!client.workspace || Number(client.workspace.id) <= 0) continue
    var address = String(client.address || "").toLowerCase()
    if (!/^0x[0-9a-f]+$/.test(address)) continue
    var title = String(client.title || "")
    var app = String(client.class || client.initialClass || "Application")
    if ((title + " " + app).toLowerCase().indexOf(needle) < 0) continue
    var history = Number(client.focusHistoryID)
    rows.push({address: address, title: title || app, app: app,
      history: Number.isFinite(history) && history >= 0 ? history : 2147483647})
  }
  rows.sort(function(a, b) { return a.history - b.history })
  return rows.slice(0, 8)
}

function launcherPrefix(query) {
  var text = String(query || "").trim()
  if (text.charAt(0) === "~") return { kind: "files", text: text.slice(1).trim() }
  if (/^cb(?:\s|$)/i.test(text)) return { kind: "clipboard", text: text.slice(2).trim() }
  var web = /^(g|dd|yt|wiki)\s+(.+)$/i.exec(text)
  if (web) return { kind: "web", engine: web[1].toLowerCase(), text: web[2].trim() }
  return { kind: "all", text: text }
}

function launcherGroup(entry) {
  if (!entry) return "Commands"
  if (entry.kind === "app") return "Apps"
  if (entry.id === "setup" || String(entry.id || "").indexOf("setup.") === 0) return "Settings"
  if (entry.kind === "menu" || entry.kind === "link") return "Browse"
  return "Commands"
}

function webSearch(query) {
  var prefix = launcherPrefix(query)
  if (prefix.kind !== "web" || !prefix.text) return null
  var engines = {
    g: { label: "Google", url: "https://www.google.com/search?q=" },
    dd: { label: "DuckDuckGo", url: "https://duckduckgo.com/?q=" },
    yt: { label: "YouTube", url: "https://www.youtube.com/results?search_query=" },
    wiki: { label: "Wikipedia", url: "https://en.wikipedia.org/w/index.php?search=" }
  }
  var engine = engines[prefix.engine]
  return engine ? { label: "Search " + engine.label + " for “" + prefix.text + "”",
    detail: engine.label + " · Open in browser", url: engine.url + encodeURIComponent(prefix.text) } : null
}

function clipboardMatches(raw, query) {
  var history
  try { history = JSON.parse(String(raw || "[]")) } catch (e) { return [] }
  if (!Array.isArray(history)) return []
  var needle = String(query || "").trim().toLowerCase()
  var rows = []
  for (var i = 0; i < history.length && rows.length < 20; i++) {
    var entry = history[i]
    if (!entry || typeof entry !== "object") continue
    if (entry.type === "text") {
      var value = String(entry.text || "").replace(/\s+/g, " ").trim()
      if (!value || (needle && value.toLowerCase().indexOf(needle) < 0)) continue
      rows.push({ index: i, label: value.slice(0, 100), detail: "Clipboard text", type: "text" })
    } else if (entry.type === "image" && !needle && entry.path) {
      rows.push({ index: i, label: "Image", detail: String(entry.capturedAt || "Clipboard image"),
        type: "image", path: String(entry.path), mime: String(entry.mime || "image/png") })
    }
  }
  return rows
}

// Commands a `checked:` expression reads a value out of. Every sibling row
// asks the same one -- Defaults > Browser has seven rows all comparing
// against `strata-default-browser` -- so the batch runs it once and the rows
// read the captured answer.
//
// The capture has to be eager. These are read inside `$(...)`, and a value
// cached while one expression runs lives in that subshell only, so a lazy
// memo never survives to the expression after it.
var GUARD_READERS = [
  "strata-default-browser",
  "strata-default-editor",
  "strata-default-terminal",
  "strata-dns"
]

// Package and command presence account for most of what the guards ask, and
// asked one at a time they are almost all fork: the shipped menu spends over
// a second on them. Answer them inside the guard process instead. These
// shadow the real commands for the batch only, so they have to agree with
// them everywhere, including for no arguments at all (present is true of
// nothing, missing is not).
//
// `rpm -q --whatprovides` resolves installed package capabilities on Fedora.
// just what they are called -- with gvim installed it reports `vim` as
// present -- so the set has to carry provides too, or `install.editor.vim`
// comes back and offers to install what is already there. A version
// constraint (`bash>=1`) is not a name any set can answer, so it goes to
// pacman itself; no shipped guard writes one.
//
function guardHelpers() {
  return '__strata_pkg_has() { rpm -q --whatprovides "$1" &>/dev/null; }\n'
    + 'strata-pkg-present() { local p; for p in "$@"; do __strata_pkg_has "$p" || return 1; done; return 0; }\n'
    + 'strata-pkg-missing() { local p; for p in "$@"; do __strata_pkg_has "$p" || return 0; done; return 1; }\n'
    + 'strata-cmd-present() { local c; for c in "$@"; do command -v "$c" &>/dev/null || return 1; done; return 0; }\n'
    + 'strata-cmd-missing() { local c; for c in "$@"; do command -v "$c" &>/dev/null || return 0; done; return 1; }\n'
}

// Substitute the captured answer into the expression rather than shadowing
// the reader with a function. `$(reader)` and the variable holding what it
// printed are interchangeable -- both strip trailing newlines, both split the
// same way unquoted -- while a function would also catch `command -v reader`,
// `VAR=x reader`, and every other form, and answer those wrong. Anything but
// the plain substitution is left alone to run the real command.
function guardPrelude(guards) {
  var prelude = guardHelpers()

  for (var i = 0; i < GUARD_READERS.length; i++) {
    // The guards arrive already substituted, so what marks a reader as wanted
    // is the slot standing in for it, not the call it replaced.
    if (guards.indexOf(guardReaderSlot(i)) < 0) continue
    // `|| :` so a reader that exits nonzero cannot take the batch down with
    // it under a login shell that turned on errexit.
    prelude += "__strata_read_" + i + "=$(" + GUARD_READERS[i] + " 2>/dev/null) || :\n"
  }

  return prelude
}

function guardReaderSlot(index) {
  return "${__strata_read_" + index + "}"
}

function substituteGuardReaders(expression) {
  for (var i = 0; i < GUARD_READERS.length; i++)
    expression = expression.split("$(" + GUARD_READERS[i] + ")").join(guardReaderSlot(i))

  return expression
}

function guardLine(id, tag, expression) {
  return "if { " + substituteGuardReaders(expression) + "; } >/dev/null 2>&1; then echo "
    + id + ":" + tag + ":1; else echo " + id + ":" + tag + ":0; fi\n"
}

// One bash script for every `when:`, `checked:` and `disabled:` in the menu,
// reporting `<id>:<w|c|d>:<0|1>` per line. Speed is the whole point: the menu
// opens on the last evaluation's answers, so however long this takes is how
// long a row can contradict the state it describes.
function guardScript(items) {
  var guards = ""
  var ids = Object.keys(items || {})

  for (var i = 0; i < ids.length; i++) {
    var entry = items[ids[i]]
    if (!entry) continue
    if (entry.when) guards += guardLine(ids[i], "w", entry.when)
    if (entry.checked) guards += guardLine(ids[i], "c", entry.checked)
    if (entry.disabled) guards += guardLine(ids[i], "d", entry.disabled)
  }

  return guards ? guardPrelude(guards) + guards : ""
}

// An action that only asks this shell to summon one of its own plugins can be
// run in-process, skipping the bash and qs ipc spawns. Anything more than the
// bare call, such as a second command or a shell-expanded payload, is left to
// bash.
function summonAction(action) {
  var launch = pluginAction(action)
  return launch && launch.method === "summon" ? {id:launch.id, payload:launch.payload} : null
}

function pluginAction(action) {
  var match = /^strata-shell shell (summon|toggle) ([A-Za-z0-9._-]+)(?: '([^']*)')?$/.exec(String(action || ""))
  if (!match) return null
  return { method:match[1], id:match[2], payload:match[3] || "{}" }
}

// Toggle changes keep their delegates and scroll position. A different result
// set gets one model reset: moving old search delegates through intermediate
// row/section layouts can leave Qt's item-view geometry out of sync.
function syncDisplayRows(model, rows) {
  var structural = model.count !== rows.length
  if (!structural) {
    for (var i = 0; i < rows.length; i++) {
      var current = model.get(i)
      if (current.itemId !== rows[i].itemId || current.section !== rows[i].section) {
        structural = true
        break
      }
    }
  }
  if (structural) {
    model.clear()
    for (var j = 0; j < rows.length; j++) model.append(rows[j])
    return {changed:true, structural:true}
  }
  var changed = false
  for (var k = 0; k < rows.length; k++) {
    var existing = model.get(k)
    for (var key in rows[k]) {
      if (existing[key] !== rows[k][key]) {
        model.setProperty(k, key, rows[k][key])
        changed = true
      }
    }
  }
  return {changed:changed, structural:false}
}

if (typeof module !== "undefined") {
  module.exports = {
    pluginAction: pluginAction,
    syncDisplayRows: syncDisplayRows,
    summonAction: summonAction,
    guardReaders: GUARD_READERS,
    guardScript: guardScript,
    stripJsonc: stripJsonc,
    normalizeAliases: normalizeAliases,
    normalizeItem: normalizeItem,
    parseMenuJsonc: parseMenuJsonc,
    mergeMenuSources: mergeMenuSources,
    mergeAppRows: mergeAppRows,
    swapProviderRows: swapProviderRows,
    item: item,
    resolveRoute: resolveRoute,
    slugify: slugify,
    depthFor: depthFor,
    pathFor: pathFor,
    parentPathFor: parentPathFor,
    isDescendantOf: isDescendantOf,
    childCount: childCount,
    isVisible: isVisible,
    isDisabled: isDisabled,
    labelFor: labelFor,
    searchableToken: searchableToken,
    leafIdFor: leafIdFor,
    nameSearchText: nameSearchText,
    termInSearchWords: termInSearchWords,
    descriptionTextMatches: descriptionTextMatches,
    matchesQuery: matchesQuery,
    searchScore: searchScore,
    displayRow: displayRow
  }
}

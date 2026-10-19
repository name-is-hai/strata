// Resolve native app names through desktop-entry identities, not title substrings.
function identity(value) {
  return String(value || "").trim().toLowerCase().replace(/\.desktop$/, "")
}

function nativeMatches(windows, entries, source) {
  var wanted = identity(source)
  if (!wanted) return []
  var slug = wanted.replace(/[^a-z0-9]+/g, "")
  var classes = [wanted]
  for (var i = 0; i < entries.length; i++) {
    var entry = entries[i]
    if (!entry) continue
    var id = identity(entry.id)
    var startup = identity(entry.startupClass)
    var name = String(entry.name || "").trim().toLowerCase()
    var aliases = [id, startup, name]
    // Reverse-DNS IDs commonly end with the app name: org.wails.netbird.
    if (id.indexOf(".") > 0) aliases.push(id.split(".").pop())
    if (startup.indexOf(".") > 0) aliases.push(startup.split(".").pop())
    var matches = aliases.some(function(alias) {
      return alias && (alias === wanted || (slug.length >= 4
        && alias.replace(/[^a-z0-9]+/g, "") === slug))
    })
    if (matches) {
      if (id) classes.push(id)
      if (startup) classes.push(startup)
    }
  }
  return windows.filter(function(win) { return classes.indexOf(identity(win.wmClass)) >= 0 })
}

if (typeof module !== "undefined") module.exports = {nativeMatches: nativeMatches}

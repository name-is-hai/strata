// Pure presentation data for the menu's native plugin list.
function aliasesFor(manifest) {
  var aliases = [String(manifest.id || ""), "plugin"]
  var widget = manifest.barWidget || {}
  var sources = [manifest.aliases, manifest.keywords, widget.aliases, widget.keywords]
  for (var i = 0; i < sources.length; i++) {
    var values = Array.isArray(sources[i]) ? sources[i] : (typeof sources[i] === "string" ? [sources[i]] : [])
    for (var j = 0; j < values.length; j++) {
      if (typeof values[j] === "string" && values[j].trim() && aliases.indexOf(values[j]) === -1) aliases.push(values[j])
    }
  }
  if (widget.displayName) aliases.push(String(widget.displayName))
  return aliases
}

function rows(manifests, registry, menuId) {
  var ids = Object.keys(manifests || {}).sort(function(a, b) {
    return String(manifests[a].name || a).localeCompare(String(manifests[b].name || b))
  })
  return ids.map(function(id) {
    var manifest = manifests[id]
    var kinds = manifest.kinds || []
    var bar = kinds.indexOf("bar") !== -1
    var widgetOnly = kinds.length === 1 && kinds[0] === "bar-widget"
    var enabled = registry.isEnabled(id) && (!widgetOnly || registry.inBar(id))
    var firstParty = manifest.__isFirstParty === true
    var detail = (firstParty ? "Built-in" : "User-installed") + " · " + String(manifest.version || "")
    if (bar && enabled) detail += " · Active bar"
    else if (!firstParty) detail += " · Del to remove"
    return {
      id: menuId + ".entry-" + encodeURIComponent(id).replace(/\./g, "%2E"), parent:menuId,
      kind:"plugin-toggle", icon:"󰐱", iconFont:"", appIcon:"", appId:id,
      label:String(manifest.name || id), title:"", target:"", description:detail,
      action:enabled ? "on" : "off", provider:"", aliases:aliasesFor(manifest), when:"", checked:"", disabled:"",
      unavailable:false, pluginFirstParty:firstParty, pluginBar:bar
    }
  })
}

// Installed visual plugins become launchable Settings entries. Management
// switches stay in Plugins, so selecting a search result opens the plugin.
function launchRows(manifests, registry) {
  var result = []
  var ids = Object.keys(manifests || {}).sort(function(a, b) {
    return String(manifests[a].name || a).localeCompare(String(manifests[b].name || b))
  })
  for (var i = 0; i < ids.length; i++) {
    var id = ids[i]
    var manifest = manifests[id]
    if (!/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(id)) continue
    if (manifest.__isFirstParty || !registry.isEnabled(id)) continue
    var kinds = manifest.kinds || []
    var standalone = kinds.indexOf("panel") !== -1 || kinds.indexOf("overlay") !== -1 || kinds.indexOf("menu") !== -1
    if (!standalone && (kinds.indexOf("bar-widget") === -1 || !registry.inBar(id))) continue
    var name = String(manifest.name || id)
    result.push({
      id:"setup.plugin-open-" + encodeURIComponent(id).replace(/\./g, "%2E"), parent:"setup",
      kind:"action", icon:"󰐱", iconFont:"", appIcon:"", appId:id,
      label:name, title:"", target:"", description:"Open " + name,
      action:"strata-shell shell summon " + id + " '{}'", plugin:id,
      provider:"", aliases:aliasesFor(manifest).concat(["open " + name]),
      when:"", checked:"", disabled:""
    })
  }
  return result
}
if (typeof module !== "undefined") module.exports = {rows:rows, launchRows:launchRows, aliasesFor:aliasesFor}
